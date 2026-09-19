import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';

final groupServiceProvider = Provider((ref) => GroupService(ref));

class GroupService {
  final Ref _ref;

  GroupService(this._ref);

  Future<List<dynamic>> getMyGroups() async {
    try {
      final client = _ref.read(apiClientProvider).client;
      final response = await client.get('/groups/my-groups');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Get groups error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createGroup(String name, String description) async {
    try {
      final client = _ref.read(apiClientProvider).client;
      final response = await client.post('/groups', data: {
        'name': name,
        'description': description,
      });

      if (response.statusCode == 201) {
        return response.data['group'];
      }
      return null;
    } catch (e) {
      print('Create group error: $e');
      rethrow;
    }
  }

  Future<bool> joinGroup(String inviteCode) async {
    try {
      final client = _ref.read(apiClientProvider).client;
      final response = await client.post('/groups/join', data: {
        'inviteCode': inviteCode,
      });

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Join group error: $e');
      return false;
    }
  }
}
