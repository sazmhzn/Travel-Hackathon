import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tt/core/app_theme.dart';
import 'package:tt/features/auth/data/auth_service.dart';
import 'package:tt/features/groups/data/group_service.dart';
import 'package:tt/features/groups/presentation/group_details_screen.dart';
import 'package:tt/features/groups/presentation/group_list_screen.dart';

/// Regression tests for the infinite-width button crash: the app theme used
/// `minimumSize: Size.fromHeight(52)` (= infinite width), which blew up any
/// button laid out in a Row or dialog actions.
class _FakeAuth extends AuthService {
  _FakeAuth(super.ref);

  @override
  Future<Map<String, dynamic>?> getProfile() async => {
        'id': 'guide-1',
        'role': 'GUIDE',
        'name': 'Test',
      };
}

class _FakeGroups extends GroupService {
  _FakeGroups(super.ref);

  @override
  Future<List<Map<String, dynamic>>> getMyGroups() async => [_group];

  @override
  Future<List<Map<String, dynamic>>> getBrowseGroups() async =>
      [(_group)..['is_member'] = true];

  @override
  Future<Map<String, dynamic>?> getGroupDetails(String groupId) async => {
        'group': _group,
        'memberCount': 1,
        'onlineCount': 0,
        'missingCount': 1,
        'members': [
          {
            'user_id': 'guide-1',
            'name': 'Test',
            'role': 'GUIDE',
            'isMissing': true,
            'lastSeen': null,
          },
        ],
      };

  static final Map<String, dynamic> _group = {
    'id': 'g1',
    'name': 'Everest Base Camp Trek',
    'description': 'Classic 12-day EBC expedition via Lukla',
    'invite_code': '204673FA',
    'created_by': 'guide-1',
    'status': 'PENDING',
    'guide_name': 'Test',
  };
}

Widget _wrap(Widget home) => ProviderScope(
      overrides: [
        authServiceProvider.overrideWith((ref) => _FakeAuth(ref)),
        groupServiceProvider.overrideWith((ref) => _FakeGroups(ref)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: home),
    );

void main() {
  testWidgets('GroupListScreen renders its cards', (tester) async {
    await tester.pumpWidget(_wrap(const GroupListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Everest Base Camp Trek'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('GroupDetailsScreen renders', (tester) async {
    await tester.pumpWidget(
      _wrap(const GroupDetailsScreen(groupId: 'g1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Everest Base Camp Trek'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
