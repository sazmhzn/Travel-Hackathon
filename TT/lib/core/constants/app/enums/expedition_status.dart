/// Expedition lifecycle, shared by every feature that shows a status pill or
/// gates guide actions.
enum ExpeditionStatus {
  pending('PENDING', 'Pending'),
  ongoing('ONGOING', 'Ongoing'),
  completed('COMPLETED', 'Completed'),
  unknown('', 'Unknown');

  const ExpeditionStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ExpeditionStatus fromApi(Object? value) {
    final normalized = value?.toString().toUpperCase();
    return ExpeditionStatus.values.firstWhere(
      (status) => status.apiValue == normalized,
      orElse: () => ExpeditionStatus.unknown,
    );
  }

  bool get isOngoing => this == ongoing;

  bool get isPending => this == pending;

  bool get isCompleted => this == completed;
}
