import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/widgets/widgets.dart';

/// Small pill used to indicate an expedition's lifecycle status.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final Color color;
    final IconData icon;
    final String label;
    switch (status) {
      case 'ONGOING':
        color = colors.success;
        icon = Icons.circle;
        label = 'Ongoing';
        break;
      case 'COMPLETED':
        color = colors.brand;
        icon = Icons.check_circle;
        label = 'Completed';
        break;
      default:
        color = colors.tertiaryText;
        icon = Icons.circle_outlined;
        label = 'Pending';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10 : 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Label + value used in the group detail summary row.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final effective = color ?? colors.brand;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: effective.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: effective.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: effective),
              const SizedBox(height: 6),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: effective,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies [value] to the clipboard and confirms with a snack bar.
Future<void> copyWithFeedback(
  BuildContext context,
  String value, {
  String label = 'Invite code',
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    AppSnackBar.show(context, '$label copied to clipboard');
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  if (error) {
    AppSnackBar.showError(context, message);
  } else {
    AppSnackBar.show(context, message);
  }
}
