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

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isAuthenticated = prefs.containsKey('jwt_token');
    
    final bool isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

    if (!isAuthenticated) {
      return isLoggingIn ? null : '/login';
    }

    if (isLoggingIn) {
      return '/groups';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/profile',
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
          path: '/groups',
          builder: (context, state) => const GroupListScreen(),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => MapScreen(
            expeditionId: state.uri.queryParameters['expeditionId'],
          ),
        ),
        GoRoute(
          path: '/radar',
          builder: (context, state) => const RadarScreen(),
        ),
      ],
    ),
  ],
);
