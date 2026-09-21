import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_semantic_colors.dart';
import 'app_sizes.dart';
import 'app_text_styles.dart';

/// Builds the app's [ThemeData] for light and dark from semantic tokens.
///
/// The `seed`/`accent`/`success`/`danger` constants are kept for backwards
/// compatibility with existing screens; prefer `context.semanticColors`.
class AppTheme {
  AppTheme._();

  static const Color seed = AppColors.teal50; // deep teal (brand)
  static const Color accent = AppColors.orange50; // safety orange
  static const Color success = AppColors.green50;
  static const Color danger = AppColors.red50;

  static ThemeData get light => _build(Brightness.light, AppSemanticColors.light);

  static ThemeData get dark => _build(Brightness.dark, AppSemanticColors.dark);

  static ThemeData _build(Brightness brightness, AppSemanticColors colors) {
    final isLight = brightness == Brightness.light;
    // Start from a generated M3 scheme so every Material role has a sensible
    // value, then override the roles our tokens own.
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal50,
      brightness: brightness,
    ).copyWith(
      primary: colors.brand,
      onPrimary: colors.onBrand,
      primaryContainer: colors.selectedSurface,
      onPrimaryContainer: colors.brand,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      secondaryContainer: isLight ? AppColors.teal10 : AppColors.teal90,
      onSecondaryContainer: isLight ? AppColors.teal70 : AppColors.teal10,
      tertiary: colors.accent,
      onTertiary: colors.onAccent,
      error: colors.danger,
      onError: colors.onDanger,
      errorContainer: colors.dangerSurface,
      onErrorContainer: colors.danger,
      surface: colors.surface,
      onSurface: colors.primaryText,
      onSurfaceVariant: colors.secondaryText,
      surfaceContainerHighest: colors.surfaceMuted,
      surfaceContainerHigh: colors.surfaceMuted,
      surfaceContainer: colors.surfaceElevated,
      outline: colors.border,
      outlineVariant: colors.border,
      inverseSurface: colors.inverseSurface,
      onInverseSurface: colors.onInverseSurface,
    );
    final textTheme = AppTextStyles.textTheme.apply(
      bodyColor: colors.primaryText,
      displayColor: colors.primaryText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.screenBackground,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.primaryText,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: colors.primaryText,
        ),
        iconTheme: IconThemeData(color: colors.primaryText),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: colors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceMuted,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: colors.tertiaryText),
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: colors.secondaryText),
        floatingLabelStyle: AppTextStyles.bodySmall.copyWith(color: colors.brand),
        errorStyle: AppTextStyles.caption.copyWith(color: colors.danger),
        prefixIconColor: colors.secondaryText,
        suffixIconColor: colors.secondaryText,
        border: _inputBorder(colors.border),
        enabledBorder: _inputBorder(colors.border),
        focusedBorder: _inputBorder(colors.brand, width: 1.5),
        errorBorder: _inputBorder(colors.danger),
        focusedErrorBorder: _inputBorder(colors.danger, width: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          backgroundColor: colors.brand,
          foregroundColor: colors.onBrand,
          disabledBackgroundColor: colors.brand.withValues(alpha: 0.4),
          disabledForegroundColor: colors.onBrand.withValues(alpha: 0.7),
          textStyle: AppTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 52),
          backgroundColor: colors.brand,
          foregroundColor: colors.onBrand,
          elevation: 0,
          textStyle: AppTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: colors.primaryText,
          side: BorderSide(color: colors.border),
          textStyle: AppTextStyles.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.brand,
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceMuted,
        side: BorderSide(color: colors.border),
        labelStyle: AppTextStyles.labelMedium.copyWith(
          color: colors.primaryText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colors.selectedSurface,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTextStyles.labelSmall.copyWith(
            color: selected ? colors.brand : colors.secondaryText,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colors.brand : colors.secondaryText,
            size: 24,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.onInverseSurface,
        ),
        actionTextColor: colors.brand,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: AppTextStyles.headlineSmall.copyWith(
          color: colors.primaryText,
        ),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: colors.secondaryText,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.bottomSheetSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.brand,
        foregroundColor: colors.onBrand,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: colors.primaryText,
        iconColor: colors.secondaryText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.brand),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
