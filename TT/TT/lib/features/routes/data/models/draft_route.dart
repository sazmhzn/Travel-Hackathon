import 'package:isar/isar.dart';

part 'draft_route.g.dart';

@collection
class DraftRoute {
  Id id = Isar.autoIncrement;

  late DateTime startTime;
  String? title;
  String? description;
  String activityType = 'trekking';
  String visibility = 'public';
  
  bool isCompleted = false;
  bool isSynced = false;
}
