import 'package:isar/isar.dart';

part 'offline_telemetry_record.g.dart';

@collection
class OfflineTelemetryRecord {
  Id id = Isar.autoIncrement;

  late String userId;
  late String groupId;
  late double lat;
  late double lng;
  late double altitude;
  late double speed;
  late int battery;
  late DateTime recordedAt;
  
  bool isSynced = false;
}
