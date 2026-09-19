import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'onboarding_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Mock regions for demonstration
  final List<Map<String, dynamic>> _regions = [
    {
      'name': 'Kathmandu Valley',
      'bounds': [27.57, 85.16, 27.80, 85.50], // minLat, minLng, maxLat, maxLng
    },
    {
      'name': 'Pokhara',
      'bounds': [28.16, 83.90, 28.30, 84.10],
    },
    {
      'name': 'Everest Region',
      'bounds': [27.70, 86.60, 28.10, 87.00],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your region')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Where would you like to travel?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a region to download offline maps before you lose signal.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          for (final region in _regions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: const Icon(Icons.terrain),
                  ),
                  title: Text(
                    region['name'],
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Bounds: ${region['bounds']}'),
                  trailing: const Icon(Icons.download_for_offline_outlined),
                  onTap: () async {
                    final bounds = region['bounds'] as List<double>;
                    await ref
                        .read(onboardingControllerProvider.notifier)
                        .saveDestination(
                          region['name'],
                          bounds[0],
                          bounds[1],
                          bounds[2],
                          bounds[3],
                        );
                    if (context.mounted) {
                      context.go('/map');
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
