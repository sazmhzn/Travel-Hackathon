/// MapLibre layer colours are hex strings, not [Color]s. Centralized here so
/// map layers stop hardcoding values inline and the encoding stays consistent.
class MapMarkerColors {
  MapMarkerColors._();

  /// Missing member marker.
  static const String missing = '#E53935';

  /// Peer currently off the route.
  static const String offRoute = '#FF3D00';

  /// Guide / member identity markers.
  static const String guide = '#1D4ED8';
  static const String member = '#EC4899';

  /// Outline around markers.
  static const String stroke = '#FFFFFF';

  /// Route pushed over the socket.
  static const String routeUpdated = '#FF8C00';

  /// A peer's shared location.
  static const String sharedLocation = '#FF00FF';

  /// Active SOS.
  static const String sos = '#FF0000';

  /// Route currently being recorded.
  static const String recording = '#0000FF';

  /// The current user's own route-relative state.
  static const String selfOffPath = '#FF0000';
  static const String selfOnPath = '#0000FF';
  static const String recordingSelf = '#00FF00';

  /// Start-of-recording marker.
  static const String start = '#FFFF00';
  static const String startStroke = '#000000';
}
