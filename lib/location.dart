import 'package:floor/floor.dart';

@entity
class Location {
  Location(this.lat, this.lon);

  @PrimaryKey(autoGenerate: true)
  int? id;

  final double lat;
  final double lon;
}
