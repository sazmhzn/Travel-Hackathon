import 'package:maplibre_gl/maplibre_gl.dart';

/// One simulated participant in the local TEST-Expedition.
class TestActor {
  final String userId;
  final String name;
  final String role;

  /// How far behind the guide this actor trails along the route, in meters.
  final double gapMeters;

  /// When true the actor is pushed off the route in the middle of the walk.
  final bool strays;

  const TestActor({
    required this.userId,
    required this.name,
    required this.role,
    required this.gapMeters,
    this.strays = false,
  });
}

/// A hardcoded, backend-free expedition used to exercise the live tracking,
/// off-path detection and render pipeline without a second device.
class TestExpedition {
  const TestExpedition._();

  static const String id = 'test-expedition';
  static const String name = 'TEST-Expedition';

  /// Kathmandu track (Thamel down to Durbar Square), extended with bends so the
  /// guide visibly leads and the straying member has room to leave the line.
  static const List<LatLng> route = [
    LatLng(27.7165, 85.3150),
    LatLng(27.7148, 85.3140),
    LatLng(27.7128, 85.3132),
    LatLng(27.7112, 85.3115),
    LatLng(27.7098, 85.3105),
    LatLng(27.7085, 85.3088),
    LatLng(27.7070, 85.3075),
    LatLng(27.7055, 85.3062),
    LatLng(27.7042, 85.3048),
    LatLng(27.7030, 85.3035),
  ];

  static const TestActor guide = TestActor(
    userId: 'test-guide',
    name: 'Guide',
    role: 'GUIDE',
    gapMeters: 0,
  );

  static const TestActor strayingMember = TestActor(
    userId: 'test-m3',
    name: 'Rajan',
    role: 'MEMBER',
    gapMeters: 75,
    strays: true,
  );

  static const List<TestActor> actors = [
    guide,
    TestActor(userId: 'test-m1', name: 'Pemba', role: 'MEMBER', gapMeters: 25),
    TestActor(userId: 'test-m2', name: 'Sunita', role: 'MEMBER', gapMeters: 50),
    strayingMember,
  ];

  /// GeoJSON FeatureCollection matching what the map's route layer expects.
  static Map<String, dynamic> routeGeoJson() => {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'title': name},
            'geometry': {
              'type': 'LineString',
              'coordinates': route
                  .map((p) => [p.longitude, p.latitude])
                  .toList(growable: false),
            },
          }
        ],
      };
}
