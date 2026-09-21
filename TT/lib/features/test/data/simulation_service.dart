import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:turf/turf.dart' as turf;

import '../../../core/socket_service.dart';
import 'test_expedition.dart';

final simulationServiceProvider =
    Provider<SimulationService>((ref) => SimulationService(ref));

/// Drives the local TEST-Expedition: every tick it advances the actors along
/// the hardcoded route and pushes their positions through the same peer
/// location stream the socket uses, so the real off-path detection and map
/// rendering run untouched.
class SimulationService {
  SimulationService(this._ref);

  final Ref _ref;

  /// How fast the guide walks the route.
  static const double speedMetersPerSecond = 20;

  /// Lateral distance the straying member drifts off the route at the peak.
  static const double strayPeakMeters = 130;

  /// Progress fraction range over which the straying member leaves the line.
  static const double strayWindowStart = 0.35;
  static const double strayWindowEnd = 0.65;

  static const Duration _tickInterval = Duration(seconds: 1);

  Timer? _timer;
  double _distance = 0;

  late final turf.Feature<turf.LineString> _line = turf.Feature<turf.LineString>(
    geometry: turf.LineString(
      coordinates: TestExpedition.route
          .map((p) => turf.Position(p.longitude, p.latitude))
          .toList(growable: false),
    ),
  );

  late final double _total = turf.length(_line, turf.Unit.meters).toDouble();

  late final double _maxGap = TestExpedition.actors
      .map((a) => a.gapMeters)
      .reduce(math.max);

  bool get isRunning => _timer != null;

  /// 0..1 progress of the guide along the route.
  double get progress => _total == 0 ? 0 : (_distance / _total).clamp(0.0, 1.0);

  void start() {
    if (_timer != null) return;
    _distance = 0;
    _emitAll();
    _timer = Timer.periodic(_tickInterval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    stop();
    _distance = 0;
  }

  void _tick() {
    _distance += speedMetersPerSecond;
    if (_distance >= _total + _maxGap) {
      _emitAll();
      stop();
      return;
    }
    _emitAll();
  }

  void _emitAll() {
    final socket = _ref.read(socketServiceProvider);
    for (final actor in TestExpedition.actors) {
      final trail = (_distance - actor.gapMeters).clamp(0.0, _total);
      var loc = _pointAt(trail);

      if (actor.strays) {
        final offset = _strayOffset(trail);
        if (offset > 0) {
          loc = _offsetPerpendicular(loc, trail, offset);
        }
      }

      socket.injectPeerLocation(
        actor.userId,
        loc.lat.toDouble(),
        loc.lng.toDouble(),
      );
    }
  }

  turf.Position _pointAt(double distance) {
    final feature = turf.along(_line, distance, turf.Unit.meters);
    final pos = feature.geometry!.coordinates;
    return turf.Position(pos.lng, pos.lat);
  }

  /// Eased 0 -> peak -> 0 over the stray window, so the member leaves and
  /// rejoins the route smoothly instead of teleporting.
  double _strayOffset(double distance) {
    if (_total == 0) return 0;
    final start = _total * strayWindowStart;
    final end = _total * strayWindowEnd;
    if (distance <= start || distance >= end) return 0;
    final f = (distance - start) / (end - start);
    return strayPeakMeters * math.sin(math.pi * f);
  }

  turf.Position _offsetPerpendicular(
    turf.Position point,
    double distance,
    double meters,
  ) {
    final ahead =
        _pointAt((distance + 10).clamp(0.0, _total));
    final behind =
        _pointAt((distance - 10).clamp(0.0, _total));
    final heading = turf.bearing(
      turf.Point(coordinates: behind),
      turf.Point(coordinates: ahead),
    );
    final displaced = turf.destination(
      turf.Point(coordinates: point),
      meters,
      heading + 90,
      turf.Unit.meters,
    );
    final pos = displaced.coordinates;
    return turf.Position(pos.lng, pos.lat);
  }
}
