import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:turf/turf.dart' as turf;
import '../../../core/database_provider.dart';
import '../../../core/api_client.dart';
import 'models/draft_route.dart';
import 'models/route_point.dart';
import '../../map/data/location_tracking_service.dart';

final routeRecordingServiceProvider = Provider((ref) => RouteRecordingService(ref));

class RouteRecordingService {
  // A fix is only persisted once the recorder has moved far enough or waited
  // long enough. Dropping redundant stationary fixes keeps route_points (and
  // the sync payload) small without losing trail shape.
  static const double _minPointDistanceMeters = 5.0;
  static const Duration _minPointInterval = Duration(seconds: 10);

  final Ref _ref;
  StreamSubscription? _locationSub;
  int? _activeRouteId;
  turf.Position? _lastStoredPosition;
  DateTime? _lastStoredAt;

  RouteRecordingService(this._ref);

  bool get isRecording => _activeRouteId != null;

  bool _shouldStore(double lat, double lng) {
    final last = _lastStoredPosition;
    final lastAt = _lastStoredAt;
    if (last == null || lastAt == null) return true;

    final movedMeters = turf.distance(
      turf.Point(coordinates: last),
      turf.Point(coordinates: turf.Position(lng, lat)),
      turf.Unit.meters,
    );
    if (movedMeters >= _minPointDistanceMeters) return true;

    return DateTime.now().difference(lastAt) >= _minPointInterval;
  }

  void _remember(double lat, double lng) {
    _lastStoredPosition = turf.Position(lng, lat);
    _lastStoredAt = DateTime.now();
  }

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

  Future<void> startRecording({
    double? initialLat,
    double? initialLng,
    String? groupId,
  }) async {
    final db = await _ref.read(databaseProvider.future);

    // Tag the recording with the expedition it belongs to, if one is active.
    final prefs = await SharedPreferences.getInstance();
    final activeGroupId = groupId ?? prefs.getString('active_group_id');
    if (groupId != null && groupId.isNotEmpty) {
      await prefs.setString('active_group_id', groupId);
    }

    final draft = DraftRoute(
      startTime: DateTime.now(),
      groupId: (activeGroupId?.isEmpty ?? true) ? null : activeGroupId,
      isCompleted: false,
    );
    _activeRouteId = await db.insert('draft_routes', draft.toMap());
    _lastStoredPosition = null;
    _lastStoredAt = null;

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
      _remember(initialLat, initialLng);
    }

    _locationSub = _ref.read(locationTrackingServiceProvider).locationStream.listen((data) async {
      if (_activeRouteId == null) return;

      final lat = (data['latitude'] as num).toDouble();
      final lng = (data['longitude'] as num).toDouble();
      if (!_shouldStore(lat, lng)) return;

      final point = RoutePoint(
        routeId: _activeRouteId!,
        latitude: lat,
        longitude: lng,
        altitude: (data['altitude'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.now(),
      );

      await db.insert('route_points', point.toMap());
      _remember(lat, lng);
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
    _locationSub = null;

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
    _lastStoredPosition = null;
    _lastStoredAt = null;

    // Trigger sync
    await syncRoute(routeId);
  }

  /// Retries every completed-but-unsynced draft route. Called on app start and
  /// from the background sync worker so offline recordings eventually reach the
  /// server instead of being lost.
  Future<void> syncPendingRoutes() async {
    final db = await _ref.read(databaseProvider.future);
    final rows = await db.query(
      'draft_routes',
      where: 'isCompleted = 1 AND isSynced = 0',
    );
    for (final row in rows) {
      await syncRoute(row['id'] as int);
    }
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
        if (draft.groupId != null) "group_id": draft.groupId,
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
