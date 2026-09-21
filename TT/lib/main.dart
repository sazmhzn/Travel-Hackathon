import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/router.dart';
import 'core/router/app_routes.dart';
import 'features/map/data/off_path_calculator.dart';
import 'core/background_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandlers();

  await OffPathCalculator.initializeNotifications();
  BackgroundSyncService.initialize();
  BackgroundSyncService.schedulePeriodicSync();

  // A rejected/expired token drops the user back to the login screen.
  ApiClient.onUnauthorized = () => router.go(AppRoutes.login);

  runApp(const ProviderScope(child: MyApp()));
}

/// Surfaces unexpected errors instead of swallowing them. In release, a failed
/// build shows a calm screen rather than the red error box.
void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) debugPrint('Uncaught: $error\n$stack');
    return true;
  };

  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const _AppErrorScreen();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WanderSafe',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Fallback for a fatal build error in release. Uses literal colors on purpose:
/// the theme itself may be what failed.
class _AppErrorScreen extends StatelessWidget {
  const _AppErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Color(0xFFF2F4F4),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Color(0xFF7A8383),
              ),
              SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191D1D),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Please restart the app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF5A6363)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
