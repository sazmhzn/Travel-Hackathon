import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';

final routeServiceProvider = Provider((ref) => RouteService(ref));

class RouteService {
  final Ref _ref;
  RouteService(this._ref);

  Future<Map<String, dynamic>> getGeoJsonRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final groupId = prefs.getString('active_group_id');
      if (groupId == null) return _getMockGeoJson();

      final client = _ref.read(apiClientProvider).client;
      final response = await client.get('/plans/group/$groupId');

      if (response.statusCode == 200 && (response.data as List).isNotEmpty) {
        // Take the latest plan
        return response.data[0]['geoJsonPayload'];
      }
    } catch (e) {
      print('Error fetching real route: $e');
    }
    return _getMockGeoJson();
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
