import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Semantic color tokens for the whole app, resolved per brightness.
///
/// Access with `context.semanticColors`. Never hardcode a `Color(0x...)` in a
/// feature widget — add a token here if something is missing.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.screenBackground,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.bottomSheetSurface,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
    required this.linkText,
    required this.brand,
    required this.onBrand,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.successSurface,
    required this.danger,
    required this.dangerSurface,
    required this.dangerBorder,
    required this.onDanger,
    required this.warning,
    required this.warningSurface,
    required this.warningBorder,
    required this.border,
    required this.selectedSurface,
    required this.selectedBorder,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.scrim,
  });

  /// Calm, light "normal" mode.
  static const AppSemanticColors light = AppSemanticColors(
    screenBackground: AppColors.neutral5,
    surface: AppColors.neutral0,
    surfaceElevated: AppColors.neutral0,
    surfaceMuted: AppColors.neutral10,
    bottomSheetSurface: AppColors.neutral2,
    inverseSurface: AppColors.neutral90,
    onInverseSurface: AppColors.neutral0,
    primaryText: AppColors.neutral90,
    secondaryText: AppColors.neutral60,
    tertiaryText: AppColors.neutral50,
    linkText: AppColors.blue50,
    brand: AppColors.teal50,
    onBrand: AppColors.neutral0,
    accent: AppColors.orange50,
    onAccent: AppColors.neutral0,
    success: AppColors.green50,
    successSurface: AppColors.green0,
    danger: AppColors.red50,
    dangerSurface: AppColors.red0,
    dangerBorder: AppColors.red20,
    onDanger: AppColors.neutral0,
    warning: AppColors.yellow50,
    warningSurface: AppColors.yellow0,
    warningBorder: AppColors.yellow30,
    border: AppColors.neutral20,
    selectedSurface: AppColors.teal0,
    selectedBorder: AppColors.teal50,
    shimmerBase: AppColors.shimmerBase,
    shimmerHighlight: AppColors.shimmerHighlight,
    scrim: AppColors.alphaBlack50,
  );

  /// Dark counterpart. Same hierarchy, brighter brand on dark surfaces.
  static const AppSemanticColors dark = AppSemanticColors(
    screenBackground: AppColors.neutral95,
    surface: AppColors.neutralDarkSurface,
    surfaceElevated: AppColors.neutral80,
    surfaceMuted: AppColors.neutral80,
    bottomSheetSurface: AppColors.neutral80,
    inverseSurface: AppColors.neutral20,
    onInverseSurface: AppColors.neutral90,
    primaryText: AppColors.neutral0,
    secondaryText: AppColors.neutral40,
    tertiaryText: AppColors.neutral50,
    linkText: AppColors.blue30,
    brand: AppColors.teal30,
    onBrand: AppColors.neutral95,
    accent: AppColors.orange40,
    onAccent: AppColors.neutral95,
    success: AppColors.green40,
    successSurface: AppColors.green95,
    danger: AppColors.red40,
    dangerSurface: AppColors.red95,
    dangerBorder: AppColors.red80,
    onDanger: AppColors.neutral95,
    warning: AppColors.yellow40,
    warningSurface: AppColors.yellow95,
    warningBorder: AppColors.yellow80,
    border: AppColors.neutral70,
    selectedSurface: AppColors.teal95,
    selectedBorder: AppColors.teal30,
    shimmerBase: AppColors.shimmerBaseDark,
    shimmerHighlight: AppColors.shimmerHighlightDark,
    scrim: AppColors.alphaBlack60,
  );

  final Color screenBackground;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color bottomSheetSurface;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;
  final Color linkText;
  final Color brand;
  final Color onBrand;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color successSurface;
  final Color danger;
  final Color dangerSurface;
  final Color dangerBorder;
  final Color onDanger;
  final Color warning;
  final Color warningSurface;
  final Color warningBorder;
  final Color border;
  final Color selectedSurface;
  final Color selectedBorder;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color scrim;

  @override
  AppSemanticColors copyWith({
    Color? screenBackground,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? bottomSheetSurface,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? primaryText,
    Color? secondaryText,
    Color? tertiaryText,
    Color? linkText,
    Color? brand,
    Color? onBrand,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? successSurface,
    Color? danger,
    Color? dangerSurface,
    Color? dangerBorder,
    Color? onDanger,
    Color? warning,
    Color? warningSurface,
    Color? warningBorder,
    Color? border,
    Color? selectedSurface,
    Color? selectedBorder,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? scrim,
  }) {
    return AppSemanticColors(
      screenBackground: screenBackground ?? this.screenBackground,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      bottomSheetSurface: bottomSheetSurface ?? this.bottomSheetSurface,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      tertiaryText: tertiaryText ?? this.tertiaryText,
      linkText: linkText ?? this.linkText,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successSurface: successSurface ?? this.successSurface,
      danger: danger ?? this.danger,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      onDanger: onDanger ?? this.onDanger,
      warning: warning ?? this.warning,
      warningSurface: warningSurface ?? this.warningSurface,
      warningBorder: warningBorder ?? this.warningBorder,
      border: border ?? this.border,
      selectedSurface: selectedSurface ?? this.selectedSurface,
      selectedBorder: selectedBorder ?? this.selectedBorder,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    Color? l(Color a, Color b) => Color.lerp(a, b, t);
    return AppSemanticColors(
      screenBackground: l(screenBackground, other.screenBackground)!,
      surface: l(surface, other.surface)!,
      surfaceElevated: l(surfaceElevated, other.surfaceElevated)!,
      surfaceMuted: l(surfaceMuted, other.surfaceMuted)!,
      bottomSheetSurface: l(bottomSheetSurface, other.bottomSheetSurface)!,
      inverseSurface: l(inverseSurface, other.inverseSurface)!,
      onInverseSurface: l(onInverseSurface, other.onInverseSurface)!,
      primaryText: l(primaryText, other.primaryText)!,
      secondaryText: l(secondaryText, other.secondaryText)!,
      tertiaryText: l(tertiaryText, other.tertiaryText)!,
      linkText: l(linkText, other.linkText)!,
      brand: l(brand, other.brand)!,
      onBrand: l(onBrand, other.onBrand)!,
      accent: l(accent, other.accent)!,
      onAccent: l(onAccent, other.onAccent)!,
      success: l(success, other.success)!,
      successSurface: l(successSurface, other.successSurface)!,
      danger: l(danger, other.danger)!,
      dangerSurface: l(dangerSurface, other.dangerSurface)!,
      dangerBorder: l(dangerBorder, other.dangerBorder)!,
      onDanger: l(onDanger, other.onDanger)!,
      warning: l(warning, other.warning)!,
      warningSurface: l(warningSurface, other.warningSurface)!,
      warningBorder: l(warningBorder, other.warningBorder)!,
      border: l(border, other.border)!,
      selectedSurface: l(selectedSurface, other.selectedSurface)!,
      selectedBorder: l(selectedBorder, other.selectedBorder)!,
      shimmerBase: l(shimmerBase, other.shimmerBase)!,
      shimmerHighlight: l(shimmerHighlight, other.shimmerHighlight)!,
      scrim: l(scrim, other.scrim)!,
    );
  }
}
