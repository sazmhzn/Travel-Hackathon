/// Central route paths. Reference these instead of raw strings so a path change
/// is a single edit.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';
  static const String profile = '/profile';
  static const String groups = '/groups';
  static const String map = '/map';
  static const String radar = '/radar';

  static String expedition(String groupId) => '/expedition/$groupId';
}
