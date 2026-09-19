class RoutePoint {
  int? id;

  int routeId;
  double latitude;
  double longitude;
  double altitude;
  DateTime timestamp;

  RoutePoint({
    this.id,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.timestamp,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'routeId': routeId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory RoutePoint.fromMap(Map<String, Object?> map) {
    return RoutePoint(
      id: map['id'] as int?,
      routeId: map['routeId'] as int,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
