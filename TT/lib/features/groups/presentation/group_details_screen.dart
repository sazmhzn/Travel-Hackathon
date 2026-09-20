import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/app_theme.dart';
import '../../../core/socket_service.dart';
import '../data/group_service.dart';
import '../../auth/data/auth_service.dart';
import 'group_widgets.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  const GroupDetailsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  Map<String, dynamic>? _details;
  List<Map<String, dynamic>> _routes = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _currentUserId;
  bool _isCurrentUserGuide = false;
  StreamSubscription? _groupEventSub;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _setupRealtime();
  }

  @override
  void dispose() {
    _groupEventSub?.cancel();
    super.dispose();
  }

  /// Refetches on membership/status/route changes from other devices, so the
  /// page never shows stale members or routes.
  void _setupRealtime() {
    final socket = ref.read(socketServiceProvider);
    socket.connect();
    socket.joinGroup(widget.groupId);
    _groupEventSub = socket.groupEventStream.listen((data) {
      if (data['groupId']?.toString() != widget.groupId) return;
      final event = data['event'];
      if (event == 'group_removed' || event == 'group_deleted') {
        _handleRemoved(deleted: event == 'group_deleted');
      } else {
        _load();
      }
    });
  }

  Future<void> _handleRemoved({bool deleted = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('active_group_id') == widget.groupId) {
      await prefs.remove('active_group_id');
      await prefs.remove('roster_${widget.groupId}');
      await prefs.remove('group_status_${widget.groupId}');
      await prefs.remove('missing_threshold_${widget.groupId}');
    }
    if (!mounted) return;
    showAppSnack(
      context,
      deleted
          ? 'This expedition was deleted.'
          : 'You were removed from this expedition.',
      error: true,
    );
    context.go('/groups');
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final profile = await ref.read(authServiceProvider).getProfile();
    final details =
        await ref.read(groupServiceProvider).getGroupDetails(widget.groupId);
    final routes =
        await ref.read(groupServiceProvider).getGroupRoutes(widget.groupId);
    // Ignore a slower, older response that would overwrite fresh data.
    if (!mounted || generation != _loadGeneration) return;
    final members = (details?['members'] as List?) ?? [];
    final currentId = profile?['id']?.toString();
    setState(() {
      _currentUserId = currentId;
      _isCurrentUserGuide = members.any((m) =>
          m['user_id']?.toString() == currentId && m['role'] == 'GUIDE');
      _details = details;
      _routes = routes;
      _isLoading = false;
    });
  }

  Future<void> _changeStatus(String status) async {
    setState(() => _isBusy = true);
    final result = await ref
        .read(groupServiceProvider)
        .setGroupStatus(widget.groupId, status);
    if (!mounted) return;
    setState(() => _isBusy = false);
    switch (result) {
      case GroupStatusUpdate.success:
        await _load();
        if (mounted) {
          final message = switch (status) {
            'ONGOING' => 'Expedition started.',
            'COMPLETED' => 'Expedition completed.',
            _ => 'Expedition reactivated. Members were cleared.',
          };
          showAppSnack(context, message);
        }
        break;
      case GroupStatusUpdate.ongoingExists:
        if (mounted) _showOngoingConflictDialog();
        break;
      case GroupStatusUpdate.failed:
        if (mounted) {
          showAppSnack(context, 'Could not update status.', error: true);
        }
    }
  }

  void _showOngoingConflictDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.hiking, size: 36),
        title: const Text('Expedition already ongoing'),
        content: const Text(
          'Complete the ongoing expedition first.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restart_alt, size: 36),
        title: const Text('Reactivate expedition?'),
        content: const Text(
          'This expedition will return to pending and all members will be '
          'removed. You can start it again with a fresh roster.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _changeStatus('PENDING');
    }
  }

  Future<void> _editExpedition() async {
    final group = _details?['group'] as Map<String, dynamic>?;
    if (group == null) return;
    final nameController =
        TextEditingController(text: group['name']?.toString() ?? '');
    final descController =
        TextEditingController(text: group['description']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit expedition',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Expedition name',
                    prefixIcon: Icon(Icons.terrain),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Use at least 3 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheetState(() => submitting = true);
                          final updated = await ref
                              .read(groupServiceProvider)
                              .updateGroup(
                                widget.groupId,
                                name: nameController.text.trim(),
                                description: descController.text.trim(),
                              );
                          if (!mounted) return;
                          setSheetState(() => submitting = false);
                          if (updated != null) {
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            await _load();
                            if (!mounted) return;
                            showAppSnack(context, 'Expedition updated.');
                          } else if (sheetContext.mounted) {
                            showAppSnack(
                              sheetContext,
                              'Could not update the expedition.',
                              error: true,
                            );
                          }
                        },
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(submitting ? 'Saving...' : 'Save changes'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(Map<String, dynamic> member) async {
    final name = member['name']?.toString() ?? 'this member';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.person_remove, size: 36),
        title: const Text('Remove member?'),
        content: Text(
          'Remove $name from this expedition? They will lose access to the group.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    final error = await ref
        .read(groupServiceProvider)
        .removeMember(widget.groupId, member['user_id'].toString());
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error == null) {
      await _load();
      if (mounted) showAppSnack(context, '$name removed.');
    } else if (mounted) {
      showAppSnack(context, error, error: true);
    }
  }

  Future<void> _confirmDelete() async {
    final name =
        _details?['group']?['name']?.toString() ?? 'this expedition';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_forever, size: 36, color: AppTheme.danger),
        title: const Text('Delete expedition?'),
        content: Text(
          'This permanently deletes "$name" and removes every member. '
          'Recorded routes are kept. This cannot be undone.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    final error = await ref.read(groupServiceProvider).deleteGroup(widget.groupId);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error == null) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('active_group_id') == widget.groupId) {
        await prefs.remove('active_group_id');
        await prefs.remove('roster_${widget.groupId}');
        await prefs.remove('group_status_${widget.groupId}');
        await prefs.remove('missing_threshold_${widget.groupId}');
      }
      if (!mounted) return;
      showAppSnack(context, 'Expedition deleted.');
      context.go('/groups');
    } else if (mounted) {
      showAppSnack(context, error, error: true);
    }
  }

  Future<void> _useForNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_group_id', widget.groupId);
    if (mounted) {
      showAppSnack(context, 'Set as your active expedition.');
      context.go('/map?expeditionId=${widget.groupId}');
    }
  }

  Future<void> _confirmDeleteRoute(Map<String, dynamic> route) async {
    final title = route['title']?.toString() ?? 'this route';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline, size: 36, color: AppTheme.danger),
        title: const Text('Delete route?'),
        content: Text(
          'This permanently deletes "$title". This cannot be undone.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBusy = true);
    final error =
        await ref.read(groupServiceProvider).deleteRoute(route['id'].toString());
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error == null) {
      await _load();
      if (mounted) showAppSnack(context, 'Route deleted.');
    } else if (mounted) {
      showAppSnack(context, error, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_details?['group']?['name']?.toString() ?? 'Expedition'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _details == null
              ? _ErrorState(onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      _headerCard(),
                      const SizedBox(height: 16),
                      _statsRow(),
                      const SizedBox(height: 8),
                      if (_isCurrentUserGuide) _guideControls(),
                      ..._routesSection(),
                      ..._missingSection(),
                      ..._membersSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _headerCard() {
    final group = _details!['group'] as Map<String, dynamic>;
    final status = (group['status'] ?? 'PENDING').toString().toUpperCase();
    final code = group['invite_code']?.toString() ?? '';
    final description = group['description']?.toString() ?? '';
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group['name']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                StatusPill(status: status),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.vpn_key, size: 18, color: scheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Invite code',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => copyWithFeedback(context, code),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _useForNavigation,
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Use for navigation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        StatTile(
          label: 'Members',
          value: '${_details!['memberCount'] ?? 0}',
          icon: Icons.groups,
        ),
        const SizedBox(width: 10),
        StatTile(
          label: 'Online',
          value: '${_details!['onlineCount'] ?? 0}',
          icon: Icons.sensors,
          color: AppTheme.success,
        ),
        const SizedBox(width: 10),
        StatTile(
          label: 'Missing',
          value: '${_details!['missingCount'] ?? 0}',
          icon: Icons.warning_amber_rounded,
          color: AppTheme.danger,
        ),
      ],
    );
  }

  Widget _guideControls() {
    final group = _details!['group'] as Map<String, dynamic>;
    final status = (group['status'] ?? 'PENDING').toString().toUpperCase();
    final pending = status == 'PENDING';
    final ongoing = status == 'ONGOING';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    ongoing ? Icons.play_circle : Icons.flag_circle_outlined,
                    color: AppTheme.success,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      pending
                          ? 'Ready to start this expedition'
                          : ongoing
                              ? 'This expedition is ongoing'
                              : 'This expedition is completed',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (pending)
                FilledButton.icon(
                  onPressed: _isBusy ? null : () => _changeStatus('ONGOING'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start expedition'),
                )
              else if (ongoing)
                FilledButton.tonalIcon(
                  onPressed: _isBusy ? null : () => _changeStatus('COMPLETED'),
                  icon: const Icon(Icons.flag),
                  label: const Text('Complete expedition'),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: _isBusy ? null : _confirmReactivate,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reactivate expedition'),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _editExpedition,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit expedition'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete expedition'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.danger,
                  side: const BorderSide(color: AppTheme.danger),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _routesSection() {
    if (!_isCurrentUserGuide) return [];
    final scheme = Theme.of(context).colorScheme;

    return [
      SectionHeader(title: 'Routes', count: _routes.length),
      if (_routes.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No routes recorded for this expedition yet. Use the map to record one.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      for (final route in _routes)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.primaryContainer.withValues(alpha: 0.3),
                foregroundColor: scheme.primary,
                child: const Icon(Icons.route),
              ),
              title: Text(
                route['title']?.toString() ?? 'Untitled route',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${_activityLabel(route['activity_type'])} · '
                '${_formatDistance(route['total_distance_meters'])} · '
                '${_relativeTime(route['created_at'])}',
              ),
              trailing: route['guide_id']?.toString() == _currentUserId
                  ? IconButton(
                      onPressed: _isBusy
                          ? null
                          : () => _confirmDeleteRoute(route),
                      tooltip: 'Delete route',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppTheme.danger,
                    )
                  : null,
            ),
          ),
        ),
    ];
  }

  List<Widget> _missingSection() {
    final members = (_details!['members'] as List).cast<Map<String, dynamic>>();
    final missing = members.where((m) => m['isMissing'] == true).toList();
    if (missing.isEmpty) return [];

    return [
      SectionHeader(title: 'Missing / no signal', count: missing.length),
      for (final member in missing)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _memberTile(member),
        ),
    ];
  }

  List<Widget> _membersSection() {
    final members = (_details!['members'] as List).cast<Map<String, dynamic>>();
    final present = members.where((m) => m['isMissing'] != true).toList();
    return [
      SectionHeader(title: 'Members', count: members.length),
      if (present.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'No members are reporting a location yet.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      for (final member in present)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _memberTile(member),
        ),
    ];
  }

  Widget _memberTile(Map<String, dynamic> member) {
    final isGuide = member['role'] == 'GUIDE';
    final canRemove = _isCurrentUserGuide &&
        !isGuide &&
        member['user_id']?.toString() != _currentUserId;
    return _MemberTile(
      member: member,
      isCurrentUser: _isCurrentUser,
      canRemove: canRemove,
      onRemove: canRemove ? () => _confirmRemoveMember(member) : null,
    );
  }

  bool _isCurrentUser(Map<String, dynamic> member) =>
      _currentUserId != null && member['user_id']?.toString() == _currentUserId;
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    this.canRemove = false,
    this.onRemove,
  });

  final Map<String, dynamic> member;
  final bool Function(Map<String, dynamic>) isCurrentUser;
  final bool canRemove;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final missing = member['isMissing'] == true;
    final isGuide = member['role'] == 'GUIDE';
    final you = isCurrentUser(member);
    final battery = member['battery'];
    final lastSeen = _relativeTime(member['lastSeen']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  (missing ? AppTheme.danger : scheme.primaryContainer)
                      .withValues(alpha: 0.18),
              foregroundColor: missing ? AppTheme.danger : scheme.primary,
              child: Text(
                _initials(member['name']?.toString() ?? '?'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          member['name']?.toString() ?? 'Unknown member',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (you)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text(
                            '(you)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _RoleChip(isGuide: isGuide),
                      const SizedBox(width: 8),
                      if (missing)
                        const Text(
                          'No signal',
                          style: TextStyle(
                            color: AppTheme.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          lastSeen,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  if (member['phone'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        member['phone'].toString(),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!missing && battery is num)
              Column(
                children: [
                  Icon(
                    _batteryIcon(battery.toInt()),
                    color: _batteryColor(battery.toInt(), scheme),
                    size: 20,
                  ),
                  Text(
                    '${battery.toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            if (canRemove && onRemove != null)
              IconButton(
                onPressed: onRemove,
                tooltip: 'Remove member',
                icon: const Icon(Icons.person_remove_outlined, size: 20),
                color: AppTheme.danger,
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.isGuide});

  final bool isGuide;

  @override
  Widget build(BuildContext context) {
    final color = isGuide ? AppTheme.accent : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isGuide ? 'Guide' : 'Member',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppTheme.danger),
            const SizedBox(height: 12),
            const Text('Could not load this expedition.'),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _formatDistance(dynamic meters) {
  if (meters is! num) return '—';
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

String _activityLabel(dynamic type) {
  final value = type?.toString() ?? '';
  if (value.isEmpty) return 'Route';
  return value[0].toUpperCase() + value.substring(1);
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _relativeTime(dynamic iso) {
  if (iso == null) return 'No recent update';
  final time = DateTime.tryParse(iso.toString());
  if (time == null) return 'No recent update';
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

IconData _batteryIcon(int level) {
  if (level >= 80) return Icons.battery_full;
  if (level >= 50) return Icons.battery_5_bar;
  if (level >= 20) return Icons.battery_3_bar;
  return Icons.battery_alert;
}

Color _batteryColor(int level, ColorScheme scheme) {
  if (level >= 50) return AppTheme.success;
  if (level >= 20) return AppTheme.accent;
  return AppTheme.danger;
}