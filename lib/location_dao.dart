import 'package:floor/floor.dart';
import 'location.dart';


@dao
abstract class LocationDao {

  @insert
  Future<void> insertLocation(Location location);

}