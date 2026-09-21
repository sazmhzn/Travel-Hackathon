import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';

final groupServiceProvider = Provider((ref) => GroupService(ref));

enum GroupStatusUpdate { success, ongoingExists, failed }

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
      debugPrint('Get groups error: $e');
      return [];
    }
  }

  /// Returns PENDING and COMPLETED expeditions visible to the current user.
  /// Guides see their own; members see every guide's expeditions.
  Future<List<Map<String, dynamic>>> getBrowseGroups() async {
    try {
      final response = await _client.get('/groups/browse');
      final data = response.data;
      final list = data is Map<String, dynamic> ? data['groups'] : data;
      if (list is List) {
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Browse groups error: $e');
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
      debugPrint('Join group error: $e');
      return 'Could not join this expedition.';
    }
  }

  /// Returns every route recorded within an expedition.
  Future<List<Map<String, dynamic>>> getGroupRoutes(String groupId) async {
    try {
      final response = await _client.get('/routes/group/$groupId');
      final data = response.data;
      final list = data is Map<String, dynamic> ? data['routes'] : data;
      if (list is List) {
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      debugPrint('Get group routes error: $e');
      return [];
    }
  }

  /// Deletes a route recorded by the current guide. Returns an error message on
  /// failure, otherwise `null`.
  Future<String?> deleteRoute(String routeId) async {
    try {
      final response = await _client.delete('/routes/$routeId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        return null;
      }
      return 'Could not delete this route.';
    } on DioException catch (e) {
      return _messageFromDio(e) ?? 'Could not delete this route.';
    } catch (e) {
      debugPrint('Delete route error: $e');
      return 'Could not delete this route.';
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
      debugPrint('Get group details error: $e');
      return null;
    }
  }

  Future<GroupStatusUpdate> setGroupStatus(
    String groupId,
    String status,
  ) async {
    try {
      final response = await _client.patch(
        '/groups/$groupId/status',
        data: {'status': status},
      );
      if (response.statusCode == 200) {
        return GroupStatusUpdate.success;
      }
      return GroupStatusUpdate.failed;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 ||
          (e.response?.data is Map &&
              (e.response!.data as Map)['error'] == 'OngoingExpeditionExists')) {
        return GroupStatusUpdate.ongoingExists;
      }
      debugPrint('Set group status error: $e');
      return GroupStatusUpdate.failed;
    } catch (e) {
      debugPrint('Set group status error: $e');
      return GroupStatusUpdate.failed;
    }
  }

  /// Stores the guide's offline hotspot credentials so members can join the
  /// expedition's local network. Guide only.
  Future<bool> setHotspot(
    String groupId, {
    required String ssid,
    required String password,
  }) async {
    try {
      final response = await _client.patch(
        '/groups/$groupId/hotspot',
        data: {'ssid': ssid, 'password': password},
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Set hotspot error: $e');
      return false;
    }
  }

  /// Updates an expedition's title and description. Guide only.
  Future<Map<String, dynamic>?> updateGroup(
    String groupId, {
    required String name,
    required String description,
  }) async {
    try {
      final response = await _client.patch(
        '/groups/$groupId',
        data: {'name': name, 'description': description},
      );
      if (response.statusCode == 200) {
        return response.data['group'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Update group error: $e');
      return null;
    }
  }

  /// Removes a member from an expedition. Guide only. Returns an error message
  /// on failure, otherwise `null`.
  Future<String?> removeMember(String groupId, String userId) async {
    try {
      final response = await _client.delete(
        '/groups/$groupId/members/$userId',
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return null;
      }
      return 'Could not remove this member.';
    } on DioException catch (e) {
      return _messageFromDio(e) ?? 'Could not remove this member.';
    } catch (e) {
      debugPrint('Remove member error: $e');
      return 'Could not remove this member.';
    }
  }

  /// Permanently deletes an expedition. Guide only. Returns an error message
  /// on failure, otherwise `null`.
  Future<String?> deleteGroup(String groupId) async {
    try {
      final response = await _client.delete('/groups/$groupId');
      if (response.statusCode == 200 || response.statusCode == 204) {
        return null;
      }
      return 'Could not delete this expedition.';
    } on DioException catch (e) {
      return _messageFromDio(e) ?? 'Could not delete this expedition.';
    } catch (e) {
      debugPrint('Delete group error: $e');
      return 'Could not delete this expedition.';
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
