import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/socket_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_semantic_colors.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/data/auth_service.dart';
import '../../groups/data/group_service.dart';

/// Devices quieter than this are treated as out of proximity range.
const int _proximityRssiThreshold = -90;

/// Development Bluetooth SIG company id, matching the native advertiser in
/// `LocationTrackerService`.
const int _companyId = 0xFFFF;

/// How often the missing-member list is re-fetched while the tab is open.
const Duration _refreshInterval = Duration(seconds: 10);

final RegExp _hex16 = RegExp(r'^[0-9a-fA-F]{16}$');

/// 8-byte identity token, mirroring `LocationTrackerService.tokenBytes`, so a
/// scanned advertisement can be matched to the member it belongs to.
List<int>? _tokenFor(String? deviceId) {
  if (deviceId == null || deviceId.isEmpty) return null;
  if (_hex16.hasMatch(deviceId)) {
    return List<int>.generate(
      8,
      (i) => int.parse(deviceId.substring(i * 2, i * 2 + 2), radix: 16),
    );
  }
  final bytes = utf8.encode(deviceId);
  return List<int>.generate(8, (i) => i < bytes.length ? bytes[i] : 0);
}

/// A missing member we want to locate via Bluetooth.
class _MissingTarget {
  const _MissingTarget({
    required this.userId,
    required this.name,
    required this.groupId,
    required this.groupName,
    this.deviceId,
    this.lat,
    this.lng,
  });

  final String userId;
  final String name;
  final String groupId;
  final String groupName;
  final String? deviceId;
  final double? lat;
  final double? lng;

  List<int>? get token => _tokenFor(deviceId);
  bool get scannable => token != null;
  bool get hasLocation => lat != null && lng != null;
}

/// A missing member and the strongest matching advertisement found, if any.
/// `result == null` means the device is not currently in range.
class _TargetStatus {
  const _TargetStatus({required this.target, required this.result});

  final _MissingTarget target;
  final ScanResult? result;

  bool get detected => result != null;
  int? get rssi => result?.rssi;
}

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> {
  List<ScanResult> _scanResults = [];
  List<_MissingTarget> _targets = [];
  bool _isScanning = false;
  bool _isLoading = true;
  bool _isGuide = false;
  String _scopeLabel = '';
  String _myName = 'A member';
  bool? _permissionGranted;
  final Set<String> _foundPeers = {};

  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _scanningSub;
  StreamSubscription<Map<String, dynamic>>? _memberFoundSub;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });
    // Listen for "found" marks from other searchers.
    final socket = ref.read(socketServiceProvider);
    socket.connect();
    _memberFoundSub = socket.memberFoundStream.listen((data) {
      final userId = data['userId']?.toString();
      if (userId == null) return;
      if (mounted) setState(() => _foundPeers.add(userId));
    });
    _loadTargets();
    // Pick up members who go missing while this tab stays open.
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (mounted) _loadTargets(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scanResultsSub?.cancel();
    _scanningSub?.cancel();
    _memberFoundSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  /// Marks a missing member as found: removes them from the list and tells the
  /// rest of the expedition so their radars clear too.
  void _markFound(_MissingTarget target) {
    setState(() => _foundPeers.add(target.userId));
    ref
        .read(socketServiceProvider)
        .markMemberFound(target.groupId, target.userId, _myName);
    if (mounted) {
      AppSnackBar.showSuccess(context, '${target.name} marked as found.');
    }
  }

  /// Opens the map centered on the member's last known location (used when the
  /// device is not in Bluetooth proximity).
  void _goToLastKnown(_MissingTarget target) {
    if (!target.hasLocation) {
      AppSnackBar.showError(context, 'No last known location for ${target.name}.');
      return;
    }
    final params = {
      if (target.groupId.isNotEmpty) 'expeditionId': target.groupId,
      'focusLat': target.lat.toString(),
      'focusLng': target.lng.toString(),
    };
    context.go(Uri(path: '/map', queryParameters: params).toString());
  }

  /// Resolves the current user's role and the missing people they may locate:
  /// guides watch their active expedition; members watch every expedition they
  /// belong to.
  Future<void> _loadTargets({bool silent = false}) async {
    final profile = await ref.read(authServiceProvider).getProfile();
    final role = (profile?['role'] ?? '').toString().toUpperCase();
    final myId = profile?['id']?.toString();
    final myName = profile?['name']?.toString();
    final groupService = ref.read(groupServiceProvider);

    final groups = await groupService.getMyGroups();
    final targets = <_MissingTarget>[];
    var scopeLabel = '';

    if (role == 'GUIDE') {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('active_group_id');
      final groupId = _resolveActiveGroupId(groups, stored);
      if (groupId != null) {
        final details = await groupService.getGroupDetails(groupId);
        _collectMissing(details, myId, targets);
        scopeLabel =
            (details?['group']?['name'] ?? 'Active expedition').toString();
      }
    } else {
      final detailsList = await Future.wait(
        groups.map((g) => groupService.getGroupDetails(g['id'].toString())),
      );
      for (final details in detailsList) {
        _collectMissing(details, myId, targets);
      }
      scopeLabel = 'All your expeditions';
    }

    if (!mounted) return;
    setState(() {
      _isGuide = role == 'GUIDE';
      _targets = targets;
      _scopeLabel = scopeLabel;
      if (myName != null && myName.isNotEmpty) _myName = myName;
      if (!silent) _isLoading = false;
    });

    _ensureScanning();
  }

  /// Prefers the stored expedition, otherwise the guide's ongoing one.
  String? _resolveActiveGroupId(
    List<Map<String, dynamic>> groups,
    String? stored,
  ) {
    if (groups.isEmpty) return null;
    if (stored != null &&
        stored.isNotEmpty &&
        groups.any((g) => g['id']?.toString() == stored)) {
      return stored;
    }
    final ongoing = groups.firstWhere(
      (g) => (g['status'] ?? '').toString().toUpperCase() == 'ONGOING',
      orElse: () => groups.first,
    );
    return ongoing['id']?.toString();
  }

  void _collectMissing(
    Map<String, dynamic>? details,
    String? myId,
    List<_MissingTarget> out,
  ) {
    if (details == null) return;
    final group = details['group'];
    final groupId = (group is Map ? group['id'] : null)?.toString() ?? '';
    final groupName =
        group is Map ? (group['name'] ?? 'Expedition').toString() : 'Expedition';
    final members = (details['members'] as List?) ?? [];

    for (final raw in members) {
      if (raw is! Map) continue;
      if (raw['isMissing'] != true) continue;
      final userId = raw['user_id']?.toString();
      final name = (raw['name'] ?? '').toString();
      if (userId == null || userId == myId || name.isEmpty) continue;
      if (_foundPeers.contains(userId)) continue;
      if (out.any((t) => t.userId == userId)) continue;
      out.add(_MissingTarget(
        userId: userId,
        name: name,
        groupId: groupId,
        groupName: groupName,
        deviceId: raw['device_id']?.toString(),
        lat: (raw['lat'] as num?)?.toDouble(),
        lng: (raw['lng'] as num?)?.toDouble(),
      ));
    }
  }

  /// Starts tracking whenever there is at least one scannable missing member.
  void _ensureScanning() {
    final hasScannable = _targets.any((t) => t.scannable);
    if (hasScannable && !_isScanning) {
      _startScan();
    } else if (!hasScannable && _isScanning) {
      FlutterBluePlus.stopScan();
    }
  }

  Future<void> _startScan() async {
    if (!await FlutterBluePlus.isSupported) return;

    if (_permissionGranted == null) {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      _permissionGranted =
          statuses[Permission.bluetoothScan]?.isGranted == true ||
              statuses[Permission.bluetoothConnect]?.isGranted == true ||
              statuses[Permission.location]?.isGranted == true;
      if (_permissionGranted == false) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            'Bluetooth permission is required to find nearby members.',
          );
        }
        return;
      }
    } else if (_permissionGranted == false) {
      return;
    }

    _scanResultsSub ??= FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _scanResults = results);
    });

    try {
      await FlutterBluePlus.stopScan();
      // Track missing members by their advertised identity token rather than
      // by name, and keep RSSI live while the tab is open.
      await FlutterBluePlus.startScan(
        withMsd: [MsdFilter(_companyId)],
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 15),
        androidScanMode: AndroidScanMode.lowLatency,
      );
    } catch (e) {
      debugPrint('Radar scan error: $e');
    }
  }

  Future<void> _toggleScan() async {
    if (_isScanning) {
      await FlutterBluePlus.stopScan();
    } else {
      await _startScan();
    }
  }

  /// Every missing member paired with the strongest matching advertisement.
  /// Detected members come first, strongest signal to weakest, then the rest.
  List<_TargetStatus> get _statuses {
    final list = _targets
        .where((t) => !_foundPeers.contains(t.userId))
        .map((target) {
      ScanResult? strongest;
      final token = target.token;
      if (token != null) {
        for (final result in _scanResults) {
          if (result.rssi < _proximityRssiThreshold) continue;
          final data = result.advertisementData.manufacturerData[_companyId];
          if (data == null || !_tokensMatch(data, token)) continue;
          if (strongest == null || result.rssi > strongest.rssi) {
            strongest = result;
          }
        }
      }
      return _TargetStatus(target: target, result: strongest);
    }).toList();

    list.sort((a, b) {
      if (a.detected != b.detected) return a.detected ? -1 : 1;
      if (a.detected && b.detected) return b.rssi!.compareTo(a.rssi!);
      return a.target.name.compareTo(b.target.name);
    });
    return list;
  }

  bool _tokensMatch(List<int> data, List<int> token) {
    if (data.length < token.length) return false;
    for (var i = 0; i < token.length; i++) {
      if (data[i] != token[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _statuses;
    final detected = statuses.where((s) => s.detected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find missing people'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoading(message: 'Loading missing members...')
          : Column(
              children: [
                _scopeHeader(detected),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _loadTargets(silent: true),
                    child: statuses.isEmpty
                        ? _EmptyRadar(isGuide: _isGuide)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: statuses.length,
                            itemBuilder: (context, index) {
                              final status = statuses[index];
                              return _RadarTile(
                                status: status,
                                onMarkFound: () => _markFound(status.target),
                                onGoToLastKnown: () =>
                                    _goToLastKnown(status.target),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleScan,
        tooltip: _isScanning ? 'Stop' : 'Refresh',
        child: Icon(_isScanning ? Icons.stop : Icons.refresh),
      ),
    );
  }

  Widget _scopeHeader(int detected) {
    final colors = context.semanticColors;
    final scope = _scopeLabel.isEmpty ? 'Watching' : _scopeLabel;
    final hasMissing = _targets.isNotEmpty;
    final tone = hasMissing ? colors.danger : colors.success;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: hasMissing ? colors.dangerSurface : colors.successSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: hasMissing
                ? colors.dangerBorder
                : colors.success.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_isGuide ? Icons.hiking : Icons.groups, color: tone),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    hasMissing
                        ? (_isGuide
                            ? 'Missing members'
                            : 'Missing people nearby')
                        : 'Everyone is accounted for',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: colors.primaryText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isScanning)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.brand,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasMissing
                  ? '$scope · ${_targets.length} missing · $detected detected'
                  : '$scope · no one missing',
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.secondaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _SignalLegendDot(color: colors.danger, label: 'Very close'),
                const SizedBox(width: AppSpacing.md),
                _SignalLegendDot(color: colors.accent, label: 'Nearby'),
                const SizedBox(width: AppSpacing.md),
                _SignalLegendDot(color: AppColors.blue50, label: 'In range'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalLegendDot extends StatelessWidget {
  const _SignalLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.semanticColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _RadarTile extends StatelessWidget {
  const _RadarTile({
    required this.status,
    required this.onMarkFound,
    required this.onGoToLastKnown,
  });

  final _TargetStatus status;
  final VoidCallback onMarkFound;
  final VoidCallback onGoToLastKnown;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final detected = status.detected;
    final rssi = status.rssi;
    final signal = detected ? _signalColor(colors, rssi!) : colors.tertiaryText;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: detected ? colors.surface : colors.surfaceMuted,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: signal.withValues(alpha: detected ? 0.15 : 0.1),
          foregroundColor: signal,
          child: Icon(
            detected ? _signalIcon(rssi!) : Icons.bluetooth_searching,
          ),
        ),
        title: Text(
          status.target.name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: detected ? colors.primaryText : colors.secondaryText,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status.target.groupName,
              style: TextStyle(color: colors.secondaryText, fontSize: 13),
            ),
            const SizedBox(height: 2),
            if (detected)
              Text(
                '${_signalLabel(rssi!)} · $rssi dBm',
                style: TextStyle(
                  color: signal,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              Text(
                status.target.scannable ? 'Not in range' : 'No Bluetooth ID',
                style: TextStyle(color: colors.tertiaryText, fontSize: 12),
              ),
          ],
        ),
        trailing: detected
            ? TextButton.icon(
                onPressed: onMarkFound,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Found'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              )
            : (status.target.hasLocation
                ? TextButton.icon(
                    onPressed: onGoToLastKnown,
                    icon: const Icon(Icons.place_outlined, size: 18),
                    label: const Text('Last location'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  )
                : const SizedBox.shrink()),
      ),
    );
  }
}

class _EmptyRadar extends StatelessWidget {
  const _EmptyRadar({required this.isGuide});

  final bool isGuide;

  @override
  Widget build(BuildContext context) {
    final message = isGuide
        ? 'No missing members in this expedition.'
        : 'No missing people across your expeditions.';

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        const SizedBox(height: AppSpacing.xl),
        AppEmptyState(
          icon: Icons.person_search_outlined,
          title: message,
          message:
              'Missing members show up here and are tracked by Bluetooth as you search.',
        ),
      ],
    );
  }
}

Color _signalColor(AppSemanticColors colors, int rssi) {
  if (rssi > -60) return colors.danger;
  if (rssi > -80) return colors.accent;
  return AppColors.blue50;
}

String _signalLabel(int rssi) {
  if (rssi > -60) return 'Very close';
  if (rssi > -80) return 'Nearby';
  return 'In range';
}

IconData _signalIcon(int rssi) {
  if (rssi > -60) return Icons.signal_cellular_alt;
  if (rssi > -80) return Icons.signal_cellular_alt_2_bar;
  return Icons.signal_cellular_alt_1_bar;
}
