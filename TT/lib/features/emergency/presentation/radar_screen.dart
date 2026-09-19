import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../groups/data/group_service.dart';

/// Devices quieter than this are treated as out of proximity range.
const int _proximityRssiThreshold = -90;

/// A missing member we want to locate via Bluetooth.
class _MissingTarget {
  const _MissingTarget({
    required this.userId,
    required this.name,
    required this.groupName,
  });

  final String userId;
  final String name;
  final String groupName;
}

/// A missing member matched to a nearby Bluetooth device.
class _ProximityHit {
  const _ProximityHit({
    required this.target,
    required this.rssi,
    required this.deviceName,
  });

  final _MissingTarget target;
  final int rssi;
  final String deviceName;
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

  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _scanningSub;

  @override
  void initState() {
    super.initState();
    _scanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => _isScanning = scanning);
    });
    _loadTargets();
  }

  @override
  void dispose() {
    _scanResultsSub?.cancel();
    _scanningSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  /// Resolves the current user's role and the missing people they may locate:
  /// guides watch their active expedition; members watch every expedition they
  /// belong to.
  Future<void> _loadTargets() async {
    final profile = await ref.read(authServiceProvider).getProfile();
    final role = (profile?['role'] ?? '').toString().toUpperCase();
    final myId = profile?['id']?.toString();
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
        scopeLabel = (details?['group']?['name'] ?? 'Active expedition').toString();
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
      _isLoading = false;
    });

    await _startScan();
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
    final groupName =
        group is Map ? (group['name'] ?? 'Expedition').toString() : 'Expedition';
    final members = (details['members'] as List?) ?? [];

    for (final raw in members) {
      if (raw is! Map) continue;
      if (raw['isMissing'] != true) continue;
      final userId = raw['user_id']?.toString();
      final name = (raw['name'] ?? '').toString();
      if (userId == null || userId == myId || name.isEmpty) continue;
      if (out.any((t) => t.userId == userId)) continue;
      out.add(_MissingTarget(userId: userId, name: name, groupName: groupName));
    }
  }

  Future<void> _startScan() async {
    if (!await FlutterBluePlus.isSupported) return;

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final granted = statuses[Permission.bluetoothScan]?.isGranted == true ||
        statuses[Permission.bluetoothConnect]?.isGranted == true ||
        statuses[Permission.location]?.isGranted == true;
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permission is required to find nearby members.',
            ),
          ),
        );
      }
      return;
    }

    _scanResultsSub ??= FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _scanResults = results);
    });

    try {
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));
    } catch (e) {
      print('Radar scan error: $e');
    }
  }

  Future<void> _toggleScan() async {
    if (_isScanning) {
      await FlutterBluePlus.stopScan();
    } else {
      await _startScan();
    }
  }

  /// Missing targets whose Bluetooth device is currently within range.
  List<_ProximityHit> get _hits {
    final hits = <_ProximityHit>[];
    for (final target in _targets) {
      final targetKey = _normalize(target.name);
      if (targetKey.isEmpty) continue;

      ScanResult? strongest;
      for (final result in _scanResults) {
        if (result.rssi < _proximityRssiThreshold) continue;
        final deviceKey = _normalize(_deviceName(result));
        if (deviceKey.isEmpty) continue;
        if (_namesMatch(deviceKey, targetKey)) {
          if (strongest == null || result.rssi > strongest.rssi) {
            strongest = result;
          }
        }
      }

      if (strongest != null) {
        hits.add(
          _ProximityHit(
            target: target,
            rssi: strongest.rssi,
            deviceName: _deviceName(strongest),
          ),
        );
      }
    }
    hits.sort((a, b) => b.rssi.compareTo(a.rssi));
    return hits;
  }

  bool _namesMatch(String deviceKey, String targetKey) =>
      deviceKey == targetKey ||
      deviceKey.contains(targetKey) ||
      targetKey.contains(deviceKey);

  String _deviceName(ScanResult result) {
    if (result.advertisementData.advName.isNotEmpty) {
      return result.advertisementData.advName;
    }
    if (result.device.advName.isNotEmpty) return result.device.advName;
    if (result.device.platformName.isNotEmpty) {
      return result.device.platformName;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proximity Radar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _scopeHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _startScan,
                    child: _hits.isEmpty
                        ? _EmptyRadar(
                            isScanning: _isScanning,
                            isGuide: _isGuide,
                            targetCount: _targets.length,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                            itemCount: _hits.length,
                            itemBuilder: (context, index) =>
                                _RadarTile(hit: _hits[index]),
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

  Widget _scopeHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            _isGuide ? Icons.hiking : Icons.groups,
            color: scheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isGuide ? 'Missing members' : 'Missing people nearby',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _scopeLabel.isEmpty
                      ? 'Watching ${_targets.length} missing'
                      : '$_scopeLabel · ${_targets.length} missing',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_isScanning)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class _RadarTile extends StatelessWidget {
  const _RadarTile({required this.hit});

  final _ProximityHit hit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _signalColor(hit.rssi);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          child: Icon(_signalIcon(hit.rssi)),
        ),
        title: Text(
          hit.target.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hit.target.groupName),
            if (hit.deviceName.isNotEmpty &&
                _normalize(hit.deviceName) != _normalize(hit.target.name))
              Text(
                'Device: ${hit.deviceName}',
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              '${_signalLabel(hit.rssi)} · ${hit.rssi} dBm',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.person_pin_circle, color: scheme.primary),
      ),
    );
  }
}

class _EmptyRadar extends StatelessWidget {
  const _EmptyRadar({
    required this.isScanning,
    required this.isGuide,
    required this.targetCount,
  });

  final bool isScanning;
  final bool isGuide;
  final int targetCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String message;
    if (targetCount == 0) {
      message = isGuide
          ? 'No missing members in this expedition.'
          : 'No missing people across your expeditions.';
    } else {
      message = isScanning
          ? 'Looking for missing members nearby...'
          : 'No missing members nearby. Tap refresh to check again.';
    }

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.person_search, size: 56, color: scheme.outline),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Signal appears when a missing member comes close.',
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

const Color _coldSignalColor = Color(0xFF2F80ED);

Color _signalColor(int rssi) {
  if (rssi > -60) return AppTheme.danger;
  if (rssi > -80) return AppTheme.accent;
  return _coldSignalColor;
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