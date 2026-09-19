import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/app_theme.dart';
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
  bool _isLoading = true;
  bool _isBusy = false;
  String? _currentUserId;
  bool _isCurrentUserGuide = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ref.read(authServiceProvider).getProfile();
    final details =
        await ref.read(groupServiceProvider).getGroupDetails(widget.groupId);
    if (!mounted) return;
    final members = (details?['members'] as List?) ?? [];
    final currentId = profile?['id']?.toString();
    setState(() {
      _currentUserId = currentId;
      _isCurrentUserGuide = members.any((m) =>
          m['user_id']?.toString() == currentId && m['role'] == 'GUIDE');
      _details = details;
      _isLoading = false;
    });
  }

  Future<void> _toggleStatus(bool isActive) async {
    setState(() => _isBusy = true);
    final updated = await ref
        .read(groupServiceProvider)
        .setGroupStatus(widget.groupId, isActive);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (updated != null) {
      await _load();
      if (mounted) {
        showAppSnack(context, isActive ? 'Expedition activated.' : 'Expedition deactivated.');
      }
    } else if (mounted) {
      showAppSnack(context, 'Could not update status.', error: true);
    }
  }

  Future<void> _useForNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_group_id', widget.groupId);
    if (mounted) {
      showAppSnack(context, 'Set as your active expedition.');
      context.go('/map');
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
                      ..._missingSection(),
                      ..._membersSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _headerCard() {
    final group = _details!['group'] as Map<String, dynamic>;
    final active = group['is_active'] != false;
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
                StatusPill(active: active),
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
    final active = (_details!['group'] as Map)['is_active'] != false;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        child: SwitchListTile(
          value: active,
          onChanged: _isBusy ? null : _toggleStatus,
          secondary: Icon(
            active ? Icons.play_circle_outline : Icons.pause_circle_outline,
          ),
          title: const Text('Expedition active'),
          subtitle: Text(
            active
                ? 'Members can join with the invite code'
                : 'Joining is paused until you reactivate',
          ),
        ),
      ),
    );
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
          child: _MemberTile(member: member, isCurrentUser: _isCurrentUser),
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
          child: _MemberTile(member: member, isCurrentUser: _isCurrentUser),
        ),
    ];
  }

  bool _isCurrentUser(Map<String, dynamic> member) =>
      _currentUserId != null && member['user_id']?.toString() == _currentUserId;
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.isCurrentUser});

  final Map<String, dynamic> member;
  final bool Function(Map<String, dynamic>) isCurrentUser;

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