import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../features/mesh/data/offline_telemetry_record.dart';
import '../features/routes/data/models/draft_route.dart';
import '../features/routes/data/models/route_point.dart';

final databaseProvider = FutureProvider<Isar>((ref) async {
  if (Isar.instanceNames.isEmpty) {
    final dir = await getApplicationDocumentsDirectory();
    return await Isar.open(
      [
        OfflineTelemetryRecordSchema,
        DraftRouteSchema,
        RoutePointSchema,
      ],
      directory: dir.path,
    );
  }
  return Isar.getInstance()!;
});
