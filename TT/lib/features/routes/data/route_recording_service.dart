import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database_provider.dart';
import '../../../core/api_client.dart';
import 'models/draft_route.dart';
import 'models/route_point.dart';
import '../../map/data/location_tracking_service.dart';

final routeRecordingServiceProvider = Provider((ref) => RouteRecordingService(ref));

class RouteRecordingService {
  final Ref _ref;
  StreamSubscription? _locationSub;
  int? _activeRouteId;

  RouteRecordingService(this._ref);

  bool get isRecording => _activeRouteId != null;

  Future<List<RoutePoint>> getActiveRoutePoints() async {
    final db = await _ref.read(databaseProvider.future);

    if (_activeRouteId == null) {
      final rows = await db.query(
        'draft_routes',
        where: 'isCompleted = 0',
        orderBy: 'id ASC',
        limit: 1,
      );
      if (rows.isEmpty) return [];
      _activeRouteId = rows.first['id'] as int;
    }

    final pointRows = await db.query(
      'route_points',
      where: 'routeId = ?',
      whereArgs: [_activeRouteId],
    );
    return pointRows.map(RoutePoint.fromMap).toList();
  }

  Future<void> startRecording({double? initialLat, double? initialLng}) async {
    final db = await _ref.read(databaseProvider.future);

    final draft = DraftRoute(startTime: DateTime.now(), isCompleted: false);
    _activeRouteId = await db.insert('draft_routes', draft.toMap());

    // Immediately add the first point if provided
    if (initialLat != null && initialLng != null) {
      await db.insert(
        'route_points',
        RoutePoint(
          routeId: _activeRouteId!,
          latitude: initialLat,
          longitude: initialLng,
          altitude: 0.0,
          timestamp: DateTime.now(),
        ).toMap(),
      );
    }

    _locationSub = _ref.read(locationTrackingServiceProvider).locationStream.listen((data) async {
      if (_activeRouteId == null) return;

      final point = RoutePoint(
        routeId: _activeRouteId!,
        latitude: (data['latitude'] as num).toDouble(),
        longitude: (data['longitude'] as num).toDouble(),
        altitude: (data['altitude'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.now(),
      );

      await db.insert('route_points', point.toMap());
    });
  }

  Future<void> stopRecording({
    required String title,
    String? description,
    String activityType = 'trekking',
    String visibility = 'public',
  }) async {
    if (_activeRouteId == null) return;

    final db = await _ref.read(databaseProvider.future);
    await _locationSub?.cancel();

    final routeId = _activeRouteId!;
    await db.update(
      'draft_routes',
      {
        'title': title,
        'description': description,
        'activityType': activityType,
        'visibility': visibility,
        'isCompleted': 1,
      },
      where: 'id = ?',
      whereArgs: [routeId],
    );

    _activeRouteId = null;

    // Trigger sync
    await syncRoute(routeId);
  }

  Future<void> syncRoute(int draftId) async {
    final db = await _ref.read(databaseProvider.future);
    final draftRows = await db.query(
      'draft_routes',
      where: 'id = ?',
      whereArgs: [draftId],
      limit: 1,
    );
    if (draftRows.isEmpty) return;
    final draft = DraftRoute.fromMap(draftRows.first);
    if (!draft.isCompleted || draft.isSynced) return;

    final pointRows = await db.query(
      'route_points',
      where: 'routeId = ?',
      whereArgs: [draftId],
    );
    final points = pointRows.map(RoutePoint.fromMap).toList();

    if (points.isEmpty) return;

    final geoJson = {
      "type": "LineString",
      "coordinates": points.map((p) => [p.longitude, p.latitude, p.altitude]).toList(),
    };

    try {
      final client = _ref.read(apiClientProvider).client;
      final response = await client.post('/routes/record', data: {
        "title": draft.title,
        "description": draft.description,
        "activity_type": draft.activityType,
        "visibility": draft.visibility,
        "geoJson": geoJson,
      });

      if (response.statusCode == 201) {
        await db.update(
          'draft_routes',
          {'isSynced': 1},
          where: 'id = ?',
          whereArgs: [draftId],
        );
      }
    } catch (e) {
      print("Failed to sync route: $e");
    }
  }
}
