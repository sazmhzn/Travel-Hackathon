import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';

final routeServiceProvider = Provider((ref) => RouteService(ref));

class RouteService {
  final Ref _ref;
  RouteService(this._ref);

  /// Builds a GeoJSON FeatureCollection from every route recorded in an
  /// expedition so both the guide and members can see it on the map.
  Future<Map<String, dynamic>?> getGroupRouteGeoJson(String groupId) async {
    try {
      final client = _ref.read(apiClientProvider).client;
      final response = await client.get('/routes/group/$groupId');
      final data = response.data;
      final list = data is Map<String, dynamic> ? data['routes'] : data;
      if (list is List && list.isNotEmpty) {
        final features = <Map<String, dynamic>>[];
        for (final route in list) {
          final path = route is Map ? route['path'] : null;
          if (path is Map && path['coordinates'] is List) {
            features.add({
              'type': 'Feature',
              'properties': {
                'title': route['title'],
                'routeId': route['id'],
              },
              'geometry': path,
            });
          }
        }
        if (features.isNotEmpty) {
          return {'type': 'FeatureCollection', 'features': features};
        }
      }
    } catch (e) {
      debugPrint('Error fetching group routes: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getGeoJsonRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupId = prefs.getString('active_group_id');
      
      // If no group is selected, do not return mock data automatically.
      if (groupId == null) return null;

      final client = _ref.read(apiClientProvider).client;
      final response = await client.get('/plans/group/$groupId');

      if (response.statusCode == 200 && (response.data as List).isNotEmpty) {
        // Take the latest plan
        return response.data[0]['geoJsonPayload'];
      }
    } catch (e) {
      debugPrint('Error fetching real route: $e');
    }
    return null;
  }

  /// Converts a GeoJSON FeatureCollection or a bare LineString geometry to a
  /// List of LatLng for math operations.
  static List<LatLng> extractPoints(Map<String, dynamic>? geoJson) {
    if (geoJson == null) return [];
    try {
      dynamic geometry;
      if (geoJson['type'] == 'FeatureCollection') {
        final features = geoJson['features'] as List;
        if (features.isEmpty) return [];
        geometry = features[0]['geometry'];
      } else {
        geometry = geoJson;
      }
      final coords = geometry['coordinates'] as List;
      return coords
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // Mock route data for Kathmandu (Thamel to Durbar Square)
  List<LatLng> getMockRoute() {
    return const [
      LatLng(27.7153, 85.3123), // Thamel
      LatLng(27.7120, 85.3110),
      LatLng(27.7080, 85.3100),
      LatLng(27.7042, 85.3065), // Durbar Square
    ];
  }
}
