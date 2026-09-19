import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

final groupServiceProvider = Provider((ref) => GroupService(ref));

class GroupService {
  final Ref _ref;

  GroupService(this._ref);

  Dio get _client => _ref.read(apiClientProvider).client;

  /// Returns all expeditions the signed-in user belongs to.
  Future<List<Map<String, dynamic>>> getMyGroups() async {
    try {
      final response = await _client.get('/groups/my-groups');
      final data = response.data;
      // Backend wraps the list as { groups: [...] }.
      final list = data is Map<String, dynamic> ? data['groups'] : data;
      if (list is List) {
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Get groups error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createGroup(
    String name,
    String description,
  ) async {
    final response = await _client.post('/groups', data: {
      'name': name,
      'description': description,
    });
    if (response.statusCode == 201) {
      return response.data['group'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// Returns `null` on success, otherwise a human-readable error message.
  Future<String?> joinGroup(String inviteCode) async {
    try {
      final response = await _client.post('/groups/join', data: {
        'inviteCode': inviteCode.trim(),
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }
      return 'Could not join this expedition.';
    } on DioException catch (e) {
      return _messageFromDio(e) ?? 'Invalid invite code.';
    } catch (e) {
      print('Join group error: $e');
      return 'Could not join this expedition.';
    }
  }

  Future<Map<String, dynamic>?> getGroupDetails(String groupId) async {
    try {
      final response = await _client.get('/groups/$groupId');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get group details error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> setGroupStatus(
    String groupId,
    bool isActive,
  ) async {
    try {
      final response = await _client.patch(
        '/groups/$groupId/status',
        data: {'isActive': isActive},
      );
      if (response.statusCode == 200) {
        return response.data['group'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Set group status error: $e');
      return null;
    }
  }

  String? _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
