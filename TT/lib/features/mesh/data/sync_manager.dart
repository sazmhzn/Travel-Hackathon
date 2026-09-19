import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/api_client.dart';
import 'offline_telemetry_record.dart';

final syncManagerProvider = Provider((ref) => SyncManager(ref));

class SyncManager {
  static const _table = 'offline_telemetry_records';

  final Ref _ref;
  Future<Database>? _db;

  SyncManager(this._ref);

  Future<Database> _database() {
    return _db ??= openDatabase(
      'tt_telemetry.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE $_table (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId TEXT NOT NULL,
  groupId TEXT NOT NULL,
  lat REAL NOT NULL,
  lng REAL NOT NULL,
  altitude REAL NOT NULL,
  speed REAL NOT NULL,
  battery INTEGER NOT NULL,
  recordedAt INTEGER NOT NULL,
  isSynced INTEGER NOT NULL DEFAULT 0
)
''');
      },
    );
  }

  Future<void> saveTelemetryRecord(OfflineTelemetryRecord record) async {
    final db = await _database();
    await db.insert(_table, record.toMap());
  }

  /// Called when internet connection is restored to upload cached records
  Future<void> syncMeshTelemetry() async {
    final db = await _database();
    final client = _ref.read(apiClientProvider).client;

    final rows = await db.query(_table, where: 'isSynced = 0');
    if (rows.isEmpty) return;

    final unsyncedRecords = rows.map(OfflineTelemetryRecord.fromMap).toList();

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
        await db.update(
          _table,
          {'isSynced': 1},
          where: 'id IN (${List.filled(unsyncedRecords.length, '?').join(',')})',
          whereArgs: unsyncedRecords.map((r) => r.id).toList(),
        );
      }
    } catch (e) {
      print("Failed to sync telemetry: $e");
    }
  }
}