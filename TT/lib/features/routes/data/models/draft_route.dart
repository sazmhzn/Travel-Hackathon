class DraftRoute {
  int? id;

  DateTime startTime;
  String? title;
  String? description;
  String activityType;
  String visibility;

  bool isCompleted;
  bool isSynced;

  DraftRoute({
    this.id,
    required this.startTime,
    this.title,
    this.description,
    this.activityType = 'trekking',
    this.visibility = 'public',
    this.isCompleted = false,
    this.isSynced = false,
  });

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'startTime': startTime.millisecondsSinceEpoch,
      'title': title,
      'description': description,
      'activityType': activityType,
      'visibility': visibility,
      'isCompleted': isCompleted ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory DraftRoute.fromMap(Map<String, Object?> map) {
    return DraftRoute(
      id: map['id'] as int?,
      startTime:
          DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      title: map['title'] as String?,
      description: map['description'] as String?,
      activityType: map['activityType'] as String? ?? 'trekking',
      visibility: map['visibility'] as String? ?? 'public',
      isCompleted: (map['isCompleted'] as int) == 1,
      isSynced: (map['isSynced'] as int) == 1,
    );
  }
}
