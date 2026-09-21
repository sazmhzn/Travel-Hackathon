import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_sizes.dart';

/// Role badge used wherever a Guide/Member is shown (profile header, member
/// rows). Guides get the safety accent, members the brand colour.
class AppRolePill extends StatelessWidget {
  const AppRolePill({super.key, required this.isGuide, this.compact = false});

  final bool isGuide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final color = isGuide ? colors.accent : colors.brand;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : 10,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        isGuide ? 'Guide' : 'Member',
        style: TextStyle(
          color: color,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
