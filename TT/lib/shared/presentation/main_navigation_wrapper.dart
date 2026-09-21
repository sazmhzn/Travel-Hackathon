import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/map/data/location_tracking_service.dart';

class MainNavigationWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const MainNavigationWrapper({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<MainNavigationWrapper> createState() =>
      _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper> {
  @override
  void initState() {
    super.initState();
    _resumeTrackingIfExpeditionOngoing();
  }

  /// Location must stay ON for the whole lifetime of a running expedition, no
  /// matter which tab is visible. The shell starts the native service as soon
  /// as the app opens (given permission) so peers never lose a member between
  /// screens.
  Future<void> _resumeTrackingIfExpeditionOngoing() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('jwt_token')) return;

    final groupId = prefs.getString('active_group_id');
    if (groupId == null || groupId.isEmpty) return;

    final status = prefs.getString('group_status_$groupId')?.toUpperCase();
    if (status != 'ONGOING') return;

    if (!await Permission.location.isGranted) return;

    await ref.read(locationTrackingServiceProvider).startTracking();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) {
          _onItemTapped(index, context);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Expeditions',
          ),
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar),
            label: 'Radar',
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/map')) {
      return 0;
    }
    if (location.startsWith('/groups')) {
      return 1;
    }
    if (location.startsWith('/radar')) {
      return 2;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/map');
        break;
      case 1:
        context.go('/groups');
        break;
      case 2:
        context.go('/radar');
        break;
    }
  }
}
