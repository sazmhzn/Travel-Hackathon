/// Relative-time and safe-parsing helpers.
///
/// Replaces the hand-rolled `_relativeTime` copies that had drifted between
/// screens. Tolerates small clock skew between device and server.
extension DateTimeX on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// "Just now", "5 min ago", "3 h ago", "2 d ago", or a short date beyond a
  /// week.
  String get timeAgo {
    final difference = DateTime.now().difference(this);
    if (difference.isNegative && difference.inMinutes.abs() < 5) {
      return 'Just now';
    }
    if (difference.isNegative) return 'In the future';
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} h ago';
    if (difference.inDays < 7) return '${difference.inDays} d ago';
    return _shortDate;
  }

  /// Compact variant for dense rows: "now", "5m", "3h", "2d".
  String get timeAgoShort {
    final difference = DateTime.now().difference(this);
    if (difference.isNegative && difference.inSeconds.abs() < 60) return 'now';
    if (difference.inSeconds < 60) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return _shortDate;
  }

  String get _shortDate => '$day/$month/$year';
}

extension NullableDateTimeX on String? {
  DateTime? get parseIsoOrNull => DateTime.tryParse(this ?? '')?.toLocal();

  /// Relative label for an ISO timestamp, or [fallback] when unparseable.
  String relativeOr(String fallback) => parseIsoOrNull?.timeAgo ?? fallback;
}
