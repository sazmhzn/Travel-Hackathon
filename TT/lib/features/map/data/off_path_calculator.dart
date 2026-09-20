import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:turf/turf.dart' as turf;

class OffPathResult {
  final bool isOffPath;
  final double distanceMeters;
  final LatLng nearestPointOnRoute;

  OffPathResult({
    required this.isOffPath,
    required this.distanceMeters,
    required this.nearestPointOnRoute,
  });
}

class OffPathCalculator {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  static OffPathResult? checkOffPath(LatLng currentLoc, List<LatLng> route, double thresholdMeters) {
    if (route.isEmpty) return null;

    final currentPoint = turf.Point(coordinates: turf.Position(currentLoc.longitude, currentLoc.latitude));
    final lineString = turf.LineString(coordinates: route.map((e) => turf.Position(e.longitude, e.latitude)).toList());

    // Calculate distance from point to line string (returns kilometers by default)
    final distanceToLineKm = turf.pointToLineDistance(currentPoint, lineString);
    final distanceMeters = distanceToLineKm * 1000;

    final bool isOff = distanceMeters > thresholdMeters;

    // Find the nearest point on the line to draw a return path
    final nearestFeature = turf.nearestPointOnLine(lineString, currentPoint);
    final nearestPos = nearestFeature.geometry?.coordinates;
    
    LatLng nearestLatLng = currentLoc;
    if (nearestPos != null) {
      nearestLatLng = LatLng(nearestPos.lat.toDouble(), nearestPos.lng.toDouble());
    }

    return OffPathResult(
      isOffPath: isOff,
      distanceMeters: distanceMeters as double,
      nearestPointOnRoute: nearestLatLng,
    );
  }

  /// Shows the "off path" notification. Call this only on the transition to
  /// off-path, not on every location update, to avoid notification spam.
  static Future<void> triggerAlert(num distance) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'off_path_channel',
      'Off Path Alerts',
      channelDescription: 'Notifications for when you stray off the route',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'Off Path Alert!',
      body: 'You are ${distance.toStringAsFixed(1)} meters away from the route.',
      notificationDetails: platformChannelSpecifics,
      payload: 'item x',
    );
  }
}
