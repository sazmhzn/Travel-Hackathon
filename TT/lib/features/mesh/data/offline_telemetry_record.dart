class OfflineTelemetryRecord {
  int? id;

  String userId;
  String groupId;
  double lat;
  double lng;
  double altitude;
  double speed;
  int battery;
  DateTime recordedAt;
  bool isSynced;

  OfflineTelemetryRecord({
    this.id,
    required this.userId,
    required this.groupId,
    required this.lat,
    required this.lng,
    required this.altitude,
    required this.speed,
    required this.battery,
    required this.recordedAt,
    this.isSynced = false,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'groupId': groupId,
      'lat': lat,
      'lng': lng,
      'altitude': altitude,
      'speed': speed,
      'battery': battery,
      'recordedAt': recordedAt.millisecondsSinceEpoch,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory OfflineTelemetryRecord.fromMap(Map<String, Object?> map) {
    return OfflineTelemetryRecord(
      id: map['id'] as int?,
      userId: map['userId'] as String,
      groupId: map['groupId'] as String,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      altitude: (map['altitude'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      battery: map['battery'] as int,
      recordedAt:
          DateTime.fromMillisecondsSinceEpoch(map['recordedAt'] as int),
      isSynced: (map['isSynced'] as int) == 1,
    );
  }
}
