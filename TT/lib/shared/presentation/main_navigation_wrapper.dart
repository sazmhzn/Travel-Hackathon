import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainNavigationWrapper extends StatelessWidget {
  final Widget child;

  const MainNavigationWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
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

  Future<void> _onItemTapped(int index, BuildContext context) async {
    final current = GoRouterState.of(context).matchedLocation;
    switch (index) {
      case 0:
        // Returning to the map from the Expeditions tab drops the expedition
        // picked with "Use for navigation" so the map is not stuck to it.
        if (current.startsWith('/groups')) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('active_group_id');
        }
        if (context.mounted) context.go('/map');
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
