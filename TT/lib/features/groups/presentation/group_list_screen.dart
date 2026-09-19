import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/group_service.dart';
import '../../auth/data/auth_service.dart';
import 'group_widgets.dart';

class GroupListScreen extends ConsumerStatefulWidget {
  const GroupListScreen({super.key});

  @override
  ConsumerState<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends ConsumerState<GroupListScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;
  bool _isBusy = false;
  String? _userRole;

  bool get _isGuide => _userRole == 'GUIDE';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await ref.read(authServiceProvider).getProfile();
    final groups = await ref.read(groupServiceProvider).getMyGroups();
    if (!mounted) return;
    setState(() {
      _userRole = profile?['role'] as String?;
      _groups = groups;
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _activeGroups =>
      _groups.where((g) => g['is_active'] != false).toList();

  List<Map<String, dynamic>> get _inactiveGroups =>
      _groups.where((g) => g['is_active'] == false).toList();

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
                  'New Expedition',
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
                  label: Text(submitting ? 'Creating...' : 'Create Expedition'),
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
                  'Join Expedition',
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
                  label: Text(submitting ? 'Joining...' : 'Join Expedition'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleStatus(Map<String, dynamic> group, bool isActive) async {
    setState(() => _isBusy = true);
    final updated = await ref
        .read(groupServiceProvider)
        .setGroupStatus(group['id'].toString(), isActive);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (updated != null) {
      await _loadData();
      if (mounted) {
        showAppSnack(
          context,
          isActive
              ? '${group['name']} is now active.'
              : '${group['name']} was deactivated.',
        );
      }
    } else if (mounted) {
      showAppSnack(
        context,
        'Only the expedition guide can change its status.',
        error: true,
      );
    }
  }

  void _showInviteCode(Map<String, dynamic> group) {
    final code = group['invite_code']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.celebration, size: 36),
        title: const Text('Expedition created'),
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
                color: Theme.of(dialogContext)
                    .colorScheme
                    .surfaceContainerHighest,
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

  void _openGroup(Map<String, dynamic> group) {
    context.push('/expedition/${group['id']}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expeditions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              if (!mounted) return;
              final router = GoRouter.of(context);
              await ref.read(authServiceProvider).logout();
              router.go('/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _groups.isEmpty
                  ? _EmptyState(isGuide: _isGuide)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: _isGuide
                          ? _buildGuideList()
                          : _buildMemberList(),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGuide ? _showCreateGroupSheet : _showJoinSheet,
        icon: Icon(_isGuide ? Icons.add : Icons.group_add),
        label: Text(_isGuide ? 'New Expedition' : 'Join Expedition'),
      ),
    );
  }

  List<Widget> _buildGuideList() {
    final active = _activeGroups;
    final inactive = _inactiveGroups;
    return [
      if (active.isNotEmpty) ...[
        SectionHeader(title: 'Active expeditions', count: active.length),
        for (final group in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GroupCard(
              group: group,
              isGuide: true,
              busy: _isBusy,
              onTap: () => _openGroup(group),
              onToggle: (value) => _toggleStatus(group, value),
            ),
          ),
      ],
      if (inactive.isNotEmpty) ...[
        SectionHeader(title: 'Deactivated', count: inactive.length),
        for (final group in inactive)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GroupCard(
              group: group,
              isGuide: true,
              busy: _isBusy,
              onTap: () => _openGroup(group),
              onToggle: (value) => _toggleStatus(group, value),
            ),
          ),
      ],
    ];
  }

  List<Widget> _buildMemberList() {
    final active = _activeGroups;
    final inactive = _inactiveGroups;
    return [
      if (active.isNotEmpty) ...[
        SectionHeader(title: 'My expeditions', count: active.length),
        for (final group in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GroupCard(
              group: group,
              isGuide: false,
              onTap: () => _openGroup(group),
            ),
          ),
      ],
      if (inactive.isNotEmpty) ...[
        SectionHeader(title: 'Deactivated', count: inactive.length),
        for (final group in inactive)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _GroupCard(
              group: group,
              isGuide: false,
              onTap: () => _openGroup(group),
            ),
          ),
      ],
    ];
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.isGuide,
    required this.onTap,
    this.onToggle,
    this.busy = false,
  });

  final Map<String, dynamic> group;
  final bool isGuide;
  final VoidCallback onTap;
  final ValueChanged<bool>? onToggle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = group['is_active'] != false;
    final code = group['invite_code']?.toString() ?? '';
    final description = group['description']?.toString() ?? '';

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
                    backgroundColor: scheme.primaryContainer,
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(active: active),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    active ? Icons.groups : Icons.pause_circle_outline,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    active
                        ? 'Members can join with the code'
                        : 'Joining is paused',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (isGuide && onToggle != null)
                    Switch(
                      value: active,
                      onChanged: busy ? null : onToggle,
                    )
                  else
                    Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ],
          ),
        ),
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
          isGuide ? 'No expeditions yet' : 'You have not joined an expedition',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          isGuide
              ? 'Create your first expedition and share the invite code with your members.'
              : 'Ask your guide for the invite code, then tap Join Expedition.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}