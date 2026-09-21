/// Shared relative-time labels used by the date/time extensions.
class DateTimeText {
  DateTimeText._();

  static const String justNow = 'Just now';
  static const String inTheFuture = 'In the future';
  static const String noUpdate = 'No recent update';

  static String minutesAgo(int minutes) => '$minutes min ago';
  static String hoursAgo(int hours) => '$hours h ago';
  static String daysAgo(int days) => '$days d ago';
}
