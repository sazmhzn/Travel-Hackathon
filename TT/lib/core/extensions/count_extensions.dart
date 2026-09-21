/// Compact social-style number formatting: `1k`, `1.5k`, `2.3M`.
extension CountX on int {
  String get formattedCount {
    if (abs() < 1000) return toString();
    if (abs() < 1000000) return '${_trim(this / 1000)}k';
    if (abs() < 1000000000) return '${_trim(this / 1000000)}M';
    return '${_trim(this / 1000000000)}B';
  }

  static String _trim(double value) {
    final rounded = (value * 10).roundToDouble() / 10;
    return rounded == rounded.truncateToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
  }
}
