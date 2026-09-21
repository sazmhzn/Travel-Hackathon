import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/group_service.dart';
import '../../auth/data/auth_service.dart';
import '../../test/data/test_expedition.dart';
import 'group_widgets.dart';

enum _GroupSort {
  newest('Newest first'),
  oldest('Oldest first'),
  alphabetical('Alphabetical (A-Z)');

  const _GroupSort(this.label);

  final String label;
}

String _statusOf(Map<String, dynamic> group) =>
    (group['status'] ?? 'PENDING').toString().toUpperCase();

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  List<Map<String, dynamic>> _myGroups = [];
  List<Map<String, dynamic>> _browseGroups = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _userRole;
  String? _currentUserId;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _GroupSort _sort = _GroupSort.newest;
  int _loadGeneration = 0;

  bool get _isGuide => _userRole == 'GUIDE';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    final profile = await ref.read(authServiceProvider).getProfile();
    final results = await Future.wait([
      ref.read(groupServiceProvider).getMyGroups(),
      ref.read(groupServiceProvider).getBrowseGroups(),
    ]);
    // Ignore a slower, older response that would overwrite fresh data.
    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      _userRole = profile?['role'] as String?;
      _currentUserId = profile?['id']?.toString();
      _myGroups = results[0];
      _browseGroups = results[1];
      _isLoading = false;
    });
  }

  /// Ongoing expeditions the signed-in user belongs to, pinned at the top.
  List<Map<String, dynamic>> get _ongoingGroups =>
      _myGroups.where((g) => _statusOf(g) == 'ONGOING').toList();

  /// Pending/completed expeditions to list. Prefers the browse endpoint, but
  /// falls back to the user's own expeditions if that call is unavailable so
  /// the page never silently appears empty.
  List<Map<String, dynamic>> get _browseSource {
    if (_browseGroups.isNotEmpty) return _browseGroups;
    return _myGroups.where((g) {
      final status = _statusOf(g);
      return status == 'PENDING' || status == 'COMPLETED';
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleGroups {
    final query = _searchQuery.trim().toLowerCase();
    final groups = _browseSource.where((g) {
      if (query.isEmpty) return true;
      final name = (g['name'] ?? '').toString().toLowerCase();
      final description = (g['description'] ?? '').toString().toLowerCase();
      final guide = (g['guide_name'] ?? '').toString().toLowerCase();
      return name.contains(query) ||
          description.contains(query) ||
          guide.contains(query);
    }).toList();

    groups.sort((a, b) {
      switch (_sort) {
        case _GroupSort.alphabetical:
          return _name(a).compareTo(_name(b));
        case _GroupSort.newest:
          return _createdAt(b).compareTo(_createdAt(a));
        case _GroupSort.oldest:
          return _createdAt(a).compareTo(_createdAt(b));
      }
    });
    return groups;
  }

  String _name(Map<String, dynamic> group) =>
      (group['name'] ?? '').toString().toLowerCase();

  DateTime _createdAt(Map<String, dynamic> group) =>
      DateTime.tryParse(group['created_at']?.toString() ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  void _showCreateGroupSheet() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showModalBottomSheet(
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
                  'Add Group',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'An invite code is generated automatically for your members.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
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
                  maxLines: 2,
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
                          try {
                            final group = await ref
                                .read(groupServiceProvider)
                                .createGroup(
                                  nameController.text.trim(),
                                  descController.text.trim(),
                                );
                            if (!mounted) return;
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            await _loadData();
                            if (!mounted) return;
                            if (group != null) {
                              _showInviteCode(group);
                            }
                          } catch (_) {
                            setSheetState(() => submitting = false);
                            if (sheetContext.mounted) {
                              showAppSnack(
                                sheetContext,
                                'Could not create the expedition.',
                                error: true,
                              );
                            }
                          }
                        },
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(submitting ? 'Creating...' : 'Create Group'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showJoinSheet() {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    showModalBottomSheet(
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
                  'Join Group',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter the invite code shared by your guide.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Invite code',
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                  validator: (v) => (v == null || v.trim().length < 4)
                      ? 'Enter a valid invite code'
                      : null,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setSheetState(() => submitting = true);
                          final error = await ref
                              .read(groupServiceProvider)
                              .joinGroup(codeController.text);
                          if (!mounted) return;
                          setSheetState(() => submitting = false);
                          if (error == null) {
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            await _loadData();
                            if (!mounted) return;
                            showAppSnack(context, 'Joined the expedition!');
                          } else if (sheetContext.mounted) {
                            showAppSnack(sheetContext, error, error: true);
                          }
                        },
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(submitting ? 'Joining...' : 'Join Group'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeStatus(Map<String, dynamic> group, String status) async {
    setState(() => _isBusy = true);
    final result = await ref
        .read(groupServiceProvider)
        .setGroupStatus(group['id'].toString(), status);
    if (!mounted) return;
    setState(() => _isBusy = false);
    switch (result) {
      case GroupStatusUpdate.success:
        await _loadData();
        if (mounted) {
          showAppSnack(
            context,
            status == 'ONGOING'
                ? '${group['name']} started.'
                : '${group['name']} completed.',
          );
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

  void _showInviteCode(Map<String, dynamic> group) {
    final code = group['invite_code']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.celebration, size: 36),
        title: const Text('Group created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              group['name']?.toString() ?? '',
              style: Theme.of(dialogContext).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Share this invite code with your members',
              style: Theme.of(dialogContext).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(
                  dialogContext,
                ).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => copyWithFeedback(dialogContext, code),
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy code'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _openGroup(Map<String, dynamic> group) async {
    await context.push('/expedition/${group['id']}');
    // Reload so start/complete actions taken inside the details page are
    // reflected on this screen when the user navigates back.
    if (mounted) await _loadData();
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search pending & completed expeditions',
          isDense: true,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expeditions'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.science_outlined),
              tooltip: 'Run TEST-Expedition',
              onPressed: () => context.go(
                '/map?expeditionId=${TestExpedition.id}',
              ),
            ),
          PopupMenuButton<_GroupSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => [
              for (final option in _GroupSort.values)
                CheckedPopupMenuItem(
                  value: option,
                  checked: option == _sort,
                  child: Text(option.label),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _searchBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: (_myGroups.isEmpty && _browseGroups.isEmpty)
                        ? _EmptyState(isGuide: _isGuide)
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            children: _buildList(),
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGuide ? _showCreateGroupSheet : _showJoinSheet,
        icon: Icon(_isGuide ? Icons.add : Icons.group_add),
        label: Text(_isGuide ? 'Add Group' : 'Join Group'),
      ),
    );
  }

  List<Widget> _buildList() {
    final ongoing = _ongoingGroups;
    final visible = _visibleGroups;
    return [
      if (ongoing.isNotEmpty) ...[
        SectionHeader(title: 'Ongoing', count: ongoing.length),
        for (final group in ongoing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GroupCard(
              group: group,
              isMember: true,
              isOwnerGuide: _isGuide,
              busy: _isBusy,
              onTap: () => _openGroup(group),
              onComplete: () => _changeStatus(group, 'COMPLETED'),
            ),
          ),
      ],
      SectionHeader(
        title: _isGuide ? 'My expeditions' : 'All expeditions',
        count: visible.length,
      ),
      if (visible.isEmpty)
        _NoResultsState(query: _searchQuery)
      else
        for (final group in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GroupCard(
              group: group,
              isMember: group['is_member'] == true,
              isOwnerGuide: _isGuide && group['created_by'] == _currentUserId,
              busy: _isBusy,
              onTap: group['is_member'] == true
                  ? () => _openGroup(group)
                  : _showJoinSheet,
              onStart: () => _changeStatus(group, 'ONGOING'),
              onEdit: () => _openGroup(group),
            ),
          ),
    ];
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.isMember,
    required this.isOwnerGuide,
    required this.onTap,
    this.onStart,
    this.onComplete,
    this.onEdit,
    this.busy = false,
  });

  final Map<String, dynamic> group;
  final bool isMember;
  final bool isOwnerGuide;
  final VoidCallback onTap;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _statusOf(group);
    final ongoing = status == 'ONGOING';
    final pending = status == 'PENDING';
    final code = group['invite_code']?.toString() ?? '';
    final description = group['description']?.toString() ?? '';
    final guideName = group['guide_name']?.toString() ?? '';

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer.withValues(
                      alpha: ongoing ? 1 : 0.5,
                    ),
                    foregroundColor: scheme.onPrimaryContainer,
                    child: const Icon(Icons.terrain),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['name']?.toString() ?? 'Untitled',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (guideName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Guide: $guideName',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(status: status),
                ],
              ),
              if (isMember && code.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => copyWithFeedback(context, code),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.copy, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _statusHint(status, isMember),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (isOwnerGuide && pending && onStart != null)
                    FilledButton.icon(
                      onPressed: busy ? null : onStart,
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: const Text('Start'),
                    )
                  else if (isOwnerGuide && ongoing && onComplete != null)
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : onComplete,
                      icon: const Icon(Icons.flag, size: 18),
                      label: const Text('Complete'),
                    )
                  else if (isOwnerGuide && onEdit != null)
                    TextButton.icon(
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Manage'),
                    )
                  else
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusHint(String status, bool isMember) {
    switch (status) {
      case 'ONGOING':
        return isMember ? 'Expedition in progress' : 'Ongoing expedition';
      case 'COMPLETED':
        return isMember ? 'Expedition finished' : 'Completed expedition';
      default:
        return isMember
            ? 'Ready to start'
            : 'Join with the invite code from the guide';
    }
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Icon(Icons.search_off, size: 56, color: scheme.outline),
          const SizedBox(height: 16),
          Text(
            query.isEmpty
                ? 'No pending or completed expeditions'
                : 'No expeditions match "$query"',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different name or clear the search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isGuide});

  final bool isGuide;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 64),
        Icon(Icons.terrain, size: 72, color: scheme.outline),
        const SizedBox(height: 16),
        Text(
          isGuide ? 'No expeditions yet' : 'No expeditions available',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          isGuide
              ? 'Create your first expedition and share the invite code with your members.'
              : 'Ask your guide for the invite code, then tap Join Group.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
