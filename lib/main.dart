import 'dart:isolate';
import 'dart:ui';

import 'package:background_locator/background_locator.dart';
import 'package:background_locator/location_dto.dart';
import 'package:background_locator/settings/android_settings.dart';
import 'package:background_locator/settings/ios_settings.dart';
import 'package:background_locator/settings/locator_settings.dart';
import 'package:background_locator_sample/location.dart';
import 'package:background_locator_sample/location_dao.dart';
import 'package:flutter/material.dart';
import 'package:location_permissions/location_permissions.dart';

import 'app_db.dart';
import 'location_callback_handler.dart';
import 'location_service_repository.dart';

void main() async{
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ReceivePort port = ReceivePort();

  bool? isRunning;
  LocationDto? lastLocation;
  late AppDB appDB;
  late LocationDao locationDao;

  @override
  Widget build(BuildContext context) {

    final start = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        child: const Text('Start'),
        onPressed: () => _onStart(),
      ),
    );

    final stop = SizedBox(
      width: double.maxFinite,
      child: ElevatedButton(
        child: const Text('Stop'),
        onPressed: () => onStop(),
      ),
    );

    String msgStatus = '-';
    if (isRunning != null) {
      if (isRunning!) {
        msgStatus = 'Is running';
      } else {
        msgStatus = 'Is not running';
      }
    }
    final status = Text('Status: $msgStatus');

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter background Locator'),
        ),
        body: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [start, stop, status],
            ),
          ),
        ),
      ),
    );
  }

  void onStop() async {
    await BackgroundLocator.unRegisterLocationUpdate();
    final _isRunning = await BackgroundLocator.isServiceRunning();
    setState(() {
      isRunning = _isRunning;
    });
  }

  void _onStart() async {
    if (await _checkLocationPermission()) {
      await _startLocator();
      final _isRunning = await BackgroundLocator.isServiceRunning();

      setState(() {
        isRunning = _isRunning;
        lastLocation = null;
      });
    }
  }

  Future<bool> _checkLocationPermission() async {
    final access = await LocationPermissions().checkPermissionStatus();
    switch (access) {
      case PermissionStatus.unknown:
      case PermissionStatus.denied:
      case PermissionStatus.restricted:
        final permission = await LocationPermissions().requestPermissions(
          permissionLevel: LocationPermissionLevel.locationAlways,
        );
        if (permission == PermissionStatus.granted) {
          return true;
        } else {
          return false;
        }
        break;
      case PermissionStatus.granted:
        return true;
        break;
      default:
        return false;
        break;
    }
  }

  Future<void> _startLocator() async {
    Map<String, dynamic> data = {'countInit': 1};
    return await BackgroundLocator.registerLocationUpdate(LocationCallbackHandler.callback,
        initCallback: LocationCallbackHandler.initCallback,
        disposeCallback: LocationCallbackHandler.disposeCallback,
        initDataCallback: data,
        iosSettings: const IOSSettings(accuracy: LocationAccuracy.NAVIGATION, distanceFilter: 0),
        autoStop: false,
        androidSettings: const AndroidSettings(
            accuracy: LocationAccuracy.NAVIGATION,
            interval: 5,
            distanceFilter: 0,
            client: LocationClient.google,
            androidNotificationSettings: AndroidNotificationSettings(
                notificationChannelName: 'Location tracking',
                notificationTitle: 'Start Location Tracking',
                notificationMsg: 'Track location in background',
                notificationBigMsg:
                    'Background location is on to keep the app up-tp-date with your location. This is required for main features to work properly when the app is not running.',
                notificationIconColor: Colors.grey,
                notificationTapCallback: LocationCallbackHandler.notificationCallback)));
  }

  @override
  void initState() {
    super.initState();

    if (IsolateNameServer.lookupPortByName(LocationServiceRepository.isolateName) != null) {
      IsolateNameServer.removePortNameMapping(LocationServiceRepository.isolateName);
    }

    IsolateNameServer.registerPortWithName(port.sendPort, LocationServiceRepository.isolateName);
    port.listen((message) async {
      await updateUI(message);
      locationDao.insertLocation(Location((message as LocationDto).latitude, message.longitude));
    });

    initPlatformState();

    $FloorAppDB.databaseBuilder('Location_DB').build().then((value) {
      appDB = value;
      locationDao = appDB.locationDao;
    });
  }

  Future<void> initPlatformState() async {
    print('Initializing ...');
    await BackgroundLocator.initialize();
    final _isRunning = await BackgroundLocator.isServiceRunning();
    setState(() {
      isRunning = _isRunning;
    });
  }

  updateUI(dynamic message) async {
    await _updateNotificationText(message);

    setState(() {
      if (message != null) {
        lastLocation = message;
      }
    });
  }

  Future<void> _updateNotificationText(LocationDto? message) async {
    if (message == null) {
      return;
    }

    await BackgroundLocator.updateNotificationText(
        title: 'New Location Received', msg: '${DateTime.now()}', bigMsg: '${message.latitude}, ${message.longitude}');
  }
}
