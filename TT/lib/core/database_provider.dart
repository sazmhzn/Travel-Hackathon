import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  return openDatabase(
    'tt_local.db',
    version: 2,
    onCreate: (db, version) async {
      await db.execute('''
CREATE TABLE draft_routes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  startTime INTEGER NOT NULL,
  title TEXT,
  description TEXT,
  activityType TEXT NOT NULL DEFAULT 'trekking',
  visibility TEXT NOT NULL DEFAULT 'public',
  groupId TEXT,
  isCompleted INTEGER NOT NULL DEFAULT 0,
  isSynced INTEGER NOT NULL DEFAULT 0
)
''');
      await db.execute('''
CREATE TABLE route_points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  routeId INTEGER NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  altitude REAL NOT NULL,
  timestamp INTEGER NOT NULL
)
''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE draft_routes ADD COLUMN groupId TEXT');
      }
    },
  );
});
