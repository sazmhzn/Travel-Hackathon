import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/emergency/presentation/radar_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/groups/presentation/group_list_screen.dart';
import '../features/groups/presentation/group_details_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../shared/presentation/main_navigation_wrapper.dart';
import 'router/app_routes.dart';
import 'storage/storage_keys.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.login,
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isAuthenticated = prefs.containsKey(StorageKeys.jwtToken);

    final bool isLoggingIn =
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register;

    if (!isAuthenticated) {
      return isLoggingIn ? null : AppRoutes.login;
    }

    if (isLoggingIn) {
      return AppRoutes.groups;
    }

    return null;
  },
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              'This page could not be found.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  ),
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/expedition/:groupId',
      builder: (context, state) => GroupDetailsScreen(
        groupId: state.pathParameters['groupId']!,
      ),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainNavigationWrapper(child: child);
      },
      routes: [
        GoRoute(
          path: AppRoutes.groups,
          builder: (context, state) => const GroupListScreen(),
        ),
        GoRoute(
          path: AppRoutes.map,
          builder: (context, state) => MapScreen(
            expeditionId: state.uri.queryParameters['expeditionId'],
            focusLat: double.tryParse(
                state.uri.queryParameters['focusLat'] ?? ''),
            focusLng: double.tryParse(
                state.uri.queryParameters['focusLng'] ?? ''),
          ),
        ),
        GoRoute(
          path: AppRoutes.radar,
          builder: (context, state) => const RadarScreen(),
        ),
      ],
    ),
  ],
);
