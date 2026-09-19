import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'features/map/data/off_path_calculator.dart';
import 'core/background_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OffPathCalculator.initializeNotifications();
  BackgroundSyncService.initialize();
  BackgroundSyncService.schedulePeriodicSync();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Travel & Emergency App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
