import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/group_service.dart';
import '../../auth/data/auth_service.dart';

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  List<dynamic> _groups = [];
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await ref.read(authServiceProvider).getProfile();
    setState(() {
      _userRole = profile?['role'];
    });
    
    final groups = await ref.read(groupServiceProvider).getMyGroups();
    setState(() {
      _groups = groups;
      _isLoading = false;
    });
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Expedition Name')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final group = await ref.read(groupServiceProvider).createGroup(nameController.text, descController.text);
              if (group != null && mounted) {
                Navigator.pop(context);
                _loadData();
                _showInviteCode(group['invite_code']);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Group'),
        content: TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Invite Code')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(groupServiceProvider).joinGroup(codeController.text);
              if (success && mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showInviteCode(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Group Created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with your members:'),
            const SizedBox(height: 16),
            SelectableText(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Expeditions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).logout();
              if (mounted) context.go('/login');
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? const Center(child: Text('No groups found. Create or join one!'))
              : ListView.builder(
                  itemCount: _groups.length,
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return ListTile(
                      leading: const Icon(Icons.terrain),
                      title: Text(group['name']),
                      subtitle: Text(group['description'] ?? ''),
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('active_group_id', group['id'].toString());
                        if (mounted) context.go('/onboarding');
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _userRole == 'GUIDE' ? _showCreateGroupDialog : _showJoinGroupDialog,
        label: Text(_userRole == 'GUIDE' ? 'New Group' : 'Join Group'),
        icon: Icon(_userRole == 'GUIDE' ? Icons.add : Icons.group_add),
      ),
    );
  }
}
