import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingControllerProvider = StateNotifierProvider<OnboardingController, bool>((ref) {
  return OnboardingController();
});

class OnboardingController extends StateNotifier<bool> {
  OnboardingController() : super(false);

  Future<void> saveDestination(String destination, double minLat, double minLng, double maxLat, double maxLng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('destination_name', destination);
    await prefs.setDouble('min_lat', minLat);
    await prefs.setDouble('min_lng', minLng);
    await prefs.setDouble('max_lat', maxLat);
    await prefs.setDouble('max_lng', maxLng);
    await prefs.setBool('onboarding_complete', true);
    state = true;
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }
}
