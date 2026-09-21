import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_semantic_colors.dart';

/// Theme, sizing and navigation helpers bound to [BuildContext].
extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  TextTheme get textTheme => theme.textTheme;

  ColorScheme get colorScheme => theme.colorScheme;

  /// Semantic colour tokens. Falls back to the light set if the extension is
  /// somehow missing so a widget never crashes on a theme misconfiguration.
  AppSemanticColors get semanticColors =>
      theme.extension<AppSemanticColors>() ?? AppSemanticColors.light;

  bool get isDark => theme.brightness == Brightness.dark;

  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => screenSize.width;

  double get screenHeight => screenSize.height;

  EdgeInsets get viewPadding => MediaQuery.paddingOf(this);

  /// True when the platform asks for reduced motion — gate animations on this.
  bool get reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  void goTo(String path, {Object? extra}) => go(path, extra: extra);

  void replaceWith(String path, {Object? extra}) => replace(path, extra: extra);

  Future<T?> pushRoute<T extends Object?>(String path, {Object? extra}) =>
      push<T>(path, extra: extra);

  void popRoute<T extends Object?>([T? result]) => pop<T>(result);
}
