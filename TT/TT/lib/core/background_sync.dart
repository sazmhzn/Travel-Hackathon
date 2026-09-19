import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import '../features/mesh/data/sync_manager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native background task started: $task");
    
    final container = ProviderContainer();
    try {
      final syncManager = container.read(syncManagerProvider);
      await syncManager.syncMeshTelemetry();
      return true;
    } catch (e) {
      print("Background sync failed: $e");
      return false;
    } finally {
      container.dispose();
    }
  });
}

class BackgroundSyncService {
  static void initialize() {
    Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: true,
    );
  }

  static void schedulePeriodicSync() {
    Workmanager().registerPeriodicTask(
      "com.example.tt.mesh_sync",
      "syncMeshTelemetryTask",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
