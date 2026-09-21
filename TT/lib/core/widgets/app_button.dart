import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_semantic_colors.dart';
import '../theme/app_sizes.dart';

enum AppButtonVariant { primary, secondary, outlined, danger }

/// Design-system button. Wraps Material buttons so styling stays consistent and
/// a loading state is always available for form submissions.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
    this.minHeight = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final enabled = onPressed != null && !isLoading;

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _foreground(colors),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final onTap = enabled ? onPressed : null;
    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: onTap,
          style: _size(colors),
          child: child,
        ),
      AppButtonVariant.secondary => FilledButton.tonal(
          onPressed: onTap,
          style: _size(colors),
          child: child,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: onTap,
          style: _size(colors),
          child: child,
        ),
      AppButtonVariant.danger => FilledButton(
          onPressed: onTap,
          style: _size(colors).copyWith(
            backgroundColor: WidgetStatePropertyAll(colors.danger),
            foregroundColor: WidgetStatePropertyAll(colors.onDanger),
          ),
          child: child,
        ),
    };

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }

  Color _foreground(AppSemanticColors colors) => switch (variant) {
        AppButtonVariant.primary => colors.onBrand,
        AppButtonVariant.secondary => colors.primaryText,
        AppButtonVariant.outlined => colors.primaryText,
        AppButtonVariant.danger => colors.onDanger,
      };

  ButtonStyle _size(AppSemanticColors colors) =>
      ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(64, minHeight)));
}
