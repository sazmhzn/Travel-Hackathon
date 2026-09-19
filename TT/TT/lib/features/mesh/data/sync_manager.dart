import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../../../core/api_client.dart';
import '../../../core/database_provider.dart';
import 'offline_telemetry_record.dart';

final syncManagerProvider = Provider((ref) => SyncManager(ref));

class SyncManager {
  final Ref _ref;

  SyncManager(this._ref);

  Future<void> saveTelemetryRecord(OfflineTelemetryRecord record) async {
    final isar = await _ref.read(databaseProvider.future);
    await isar.writeTxn(() async {
      await isar.offlineTelemetryRecords.put(record);
    });
  }

  /// Called when internet connection is restored to upload cached records
  Future<void> syncMeshTelemetry() async {
    final isar = await _ref.read(databaseProvider.future);
    final client = _ref.read(apiClientProvider).client;

    final unsyncedRecords = await isar.offlineTelemetryRecords
        .filter()
        .isSyncedEqualTo(false)
        .findAll();

    if (unsyncedRecords.isEmpty) return;

    final recordsJson = unsyncedRecords.map((r) => {
      "userId": r.userId,
      "groupId": r.groupId,
      "lat": r.lat,
      "lng": r.lng,
      "altitude": r.altitude,
      "speed": r.speed,
      "battery": r.battery,
      "recordedAt": r.recordedAt.toIso8601String()
    }).toList();

    try {
      final response = await client.post(
        '/telemetry/mesh-sync',
        data: { "records": recordsJson }
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Mark as synced
        await isar.writeTxn(() async {
          for (var record in unsyncedRecords) {
            record.isSynced = true;
            await isar.offlineTelemetryRecords.put(record);
          }
        });
      }
    } catch (e) {
      print("Failed to sync telemetry: $e");
    }
  }
}
