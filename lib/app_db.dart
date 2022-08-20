import 'dart:async';

import 'package:background_locator_sample/location.dart';
import 'package:background_locator_sample/location_dao.dart';
import 'package:floor/floor.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

part 'app_db.g.dart';

@Database(version: 1, entities: [Location])
abstract class AppDB extends FloorDatabase {
  LocationDao get locationDao;

  static AppDB? _instance;

  static getInstance() async{
    _instance ??= await $FloorAppDB.databaseBuilder('location_db').build();
    return _instance;
  }

}
