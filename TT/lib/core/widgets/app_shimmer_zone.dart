import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../extensions/context_extensions.dart';

/// Wraps a widget tree in a themed shimmer. Pass `enabled: isLoading` and keep
/// rendering the real widget (with placeholder data) underneath.
class AppShimmerZone extends StatelessWidget {
  const AppShimmerZone({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration,
  });

  final Widget child;
  final bool enabled;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final effect = ShimmerEffect(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      duration: duration ?? const Duration(milliseconds: 1400),
    );
    return Skeletonizer(enabled: enabled, effect: effect, child: child);
  }
}

/// Single skeleton block. Use inside [AppShimmerZone] for hand-built mirrors.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Bone(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
