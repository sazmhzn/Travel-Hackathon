import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
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
    if (_activeRouteId == null) {
      final isar = await _ref.read(databaseProvider.future);
      final activeDraft = await isar.draftRoutes.filter().isCompletedEqualTo(false).findFirst();
      if (activeDraft == null) return [];
      _activeRouteId = activeDraft.id;
    }

    final isar = await _ref.read(databaseProvider.future);
    return await isar.routePoints
        .filter()
        .routeIdEqualTo(_activeRouteId!)
        .findAll();
  }

  Future<void> startRecording({double? initialLat, double? initialLng}) async {
    final isar = await _ref.read(databaseProvider.future);
    
    final draft = DraftRoute()
      ..startTime = DateTime.now()
      ..isCompleted = false;

    await isar.writeTxn(() async {
      _activeRouteId = await isar.draftRoutes.put(draft);
      
      // Immediately add the first point if provided
      if (initialLat != null && initialLng != null) {
        final firstPoint = RoutePoint()
          ..routeId = _activeRouteId!
          ..latitude = initialLat
          ..longitude = initialLng
          ..altitude = 0.0
          ..timestamp = DateTime.now();
        await isar.routePoints.put(firstPoint);
      }
    });

    _locationSub = _ref.read(locationTrackingServiceProvider).locationStream.listen((data) async {
      if (_activeRouteId == null) return;
      
      final point = RoutePoint()
        ..routeId = _activeRouteId!
        ..latitude = data['latitude']
        ..longitude = data['longitude']
        ..altitude = data['altitude'] ?? 0.0
        ..timestamp = DateTime.now();

      await isar.writeTxn(() async {
        await isar.routePoints.put(point);
      });
    });
  }

  Future<void> stopRecording({
    required String title,
    String? description,
    String activityType = 'trekking',
    String visibility = 'public',
  }) async {
    if (_activeRouteId == null) return;
    
    final isar = await _ref.read(databaseProvider.future);
    await _locationSub?.cancel();

    final draft = await isar.draftRoutes.get(_activeRouteId!);
    if (draft != null) {
      draft.title = title;
      draft.description = description;
      draft.activityType = activityType;
      draft.visibility = visibility;
      draft.isCompleted = true;

      await isar.writeTxn(() async {
        await isar.draftRoutes.put(draft);
      });
    }

    final routeId = _activeRouteId!;
    _activeRouteId = null;

    // Trigger sync
    await syncRoute(routeId);
  }

  Future<void> syncRoute(int draftId) async {
    final isar = await _ref.read(databaseProvider.future);
    final draft = await isar.draftRoutes.get(draftId);
    if (draft == null || !draft.isCompleted || draft.isSynced) return;

    final points = await isar.routePoints
        .filter()
        .routeIdEqualTo(draftId)
        .findAll();

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
        draft.isSynced = true;
        await isar.writeTxn(() async {
          await isar.collection<DraftRoute>().put(draft);
        });
      }
    } catch (e) {
      print("Failed to sync route: $e");
    }
  }
}
