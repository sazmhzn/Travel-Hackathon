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
  final TextEditingController _controller = TextEditingController();

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
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Onboarding')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where would you like to travel?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('Select a region to download offline maps:'),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _regions.length,
                itemBuilder: (context, index) {
                  final region = _regions[index];
                  return ListTile(
                    title: Text(region['name']),
                    subtitle: Text('Bounds: ${region['bounds']}'),
                    onTap: () async {
                      final bounds = region['bounds'] as List<double>;
                      await ref.read(onboardingControllerProvider.notifier).saveDestination(
                            region['name'],
                            bounds[0],
                            bounds[1],
                            bounds[2],
                            bounds[3],
                          );
                      if (mounted) {
                        context.go('/map');
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
