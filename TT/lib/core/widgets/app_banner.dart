import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../theme/app_sizes.dart';

/// Severity for [AppBanner]. `danger` is reserved for genuine emergencies,
/// `warning` for degraded-but-safe conditions (e.g. offline), `info` for calm
/// status, `success` for confirmations.
enum AppBannerTone { info, success, warning, danger }

/// Full-width status banner used over the map and at the top of screens.
///
/// Emphatic tones (danger/success) use a solid fill; calm tones (warning/info)
/// use a soft surface with a coloured icon so "offline" never shouts as loud as
/// a missing person.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.message,
    this.tone = AppBannerTone.info,
    this.icon,
    this.onTap,
    this.trailing,
    this.iconOverride,
  });

  final String message;
  final AppBannerTone tone;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final IconData? iconOverride;

  @override
  Widget build(BuildContext context) {
    final colors = context.semanticColors;
    final IconData resolvedIcon = iconOverride ??
        switch (tone) {
          AppBannerTone.info => Icons.info_outline,
          AppBannerTone.success => Icons.check_circle_outline,
          AppBannerTone.warning => Icons.warning_amber_rounded,
          AppBannerTone.danger => Icons.warning_rounded,
        };

    final (Color background, Color foreground, Color leading, Color? border) =
        switch (tone) {
      AppBannerTone.danger => (
          colors.danger,
          colors.onDanger,
          colors.onDanger,
          null,
        ),
      AppBannerTone.success => (
          colors.success,
          colors.onBrand,
          colors.onBrand,
          null,
        ),
      AppBannerTone.warning => (
          colors.warningSurface,
          colors.primaryText,
          colors.warning,
          colors.warningBorder,
        ),
      AppBannerTone.info => (
          colors.surfaceMuted,
          colors.primaryText,
          colors.linkText,
          colors.border,
        ),
    };

    final content = Row(
      children: [
        Icon(resolvedIcon, size: 20, color: leading),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: context.textTheme.bodySmall?.copyWith(color: foreground),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: border == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: border),
                ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: content,
        ),
      ),
    );
  }
}
