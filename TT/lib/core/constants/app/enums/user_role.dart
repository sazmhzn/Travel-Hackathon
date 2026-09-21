/// Signed-in user role. Guides manage expeditions; members join with a code.
enum UserRole {
  guide('GUIDE', 'Guide'),
  member('MEMBER', 'Member');

  const UserRole(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static UserRole fromApi(Object? value) {
    final normalized = value?.toString().toUpperCase();
    return UserRole.values.firstWhere(
      (role) => role.apiValue == normalized,
      orElse: () => UserRole.member,
    );
  }

  bool get isGuide => this == guide;
}
