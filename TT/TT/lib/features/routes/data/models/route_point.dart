import 'package:isar/isar.dart';

part 'route_point.g.dart';

@collection
class RoutePoint {
  Id id = Isar.autoIncrement;

  late int routeId;
  late double latitude;
  late double longitude;
  late double altitude;
  late DateTime timestamp;
}
