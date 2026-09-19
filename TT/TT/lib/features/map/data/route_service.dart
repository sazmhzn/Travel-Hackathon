import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';

final routeServiceProvider = Provider((ref) => RouteService(ref));

class RouteService {
  final Ref _ref;
  RouteService(this._ref);

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
      print('Error fetching real route: $e');
    }
    return null;
  }

  /// Converts a GeoJSON Map to a List of LatLng for math operations
  static List<LatLng> extractPoints(Map<String, dynamic>? geoJson) {
    if (geoJson == null) return [];
    try {
      final features = geoJson['features'] as List;
      if (features.isEmpty) return [];
      final geometry = features[0]['geometry'];
      final coords = geometry['coordinates'] as List;
      return coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
    } catch (e) {
      return [];
    }
  }

  Map<String, dynamic> _getMockGeoJson() {
    final route = getMockRoute();
    final coordinates = route.map((latLng) => [latLng.longitude, latLng.latitude]).toList();
    return {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "type": "LineString",
            "coordinates": coordinates,
          }
        }
      ]
    };
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

  // Generate GeoJSON Feature Collection from the route as a Map
  Map<String, dynamic> _generateGeoJsonRoute() {
    final route = getMockRoute();
    final coordinates = route.map((latLng) => [latLng.longitude, latLng.latitude]).toList();

    return {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "properties": {},
          "geometry": {
            "type": "LineString",
            "coordinates": coordinates,
          }
        }
      ]
    };
  }
}
