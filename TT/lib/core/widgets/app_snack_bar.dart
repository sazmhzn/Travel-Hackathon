import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';

/// One snackbar implementation for the whole app.
///
/// Uses the themed floating snackbar; error/success tones override the
/// background so severity reads at a glance.
class AppSnackBar {
  AppSnackBar._();

  static void show(BuildContext context, String message) => _show(context, message);

  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, tone: _Tone.success);

  static void showError(BuildContext context, String message) =>
      _show(context, message, tone: _Tone.error);

  static void _show(
    BuildContext context,
    String message, {
    _Tone tone = _Tone.neutral,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final colors = context.semanticColors;

    final (Color background, Color foreground) = switch (tone) {
      _Tone.neutral => (colors.inverseSurface, colors.onInverseSurface),
      _Tone.success => (colors.success, colors.onBrand),
      _Tone.error => (colors.danger, colors.onDanger),
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: context.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}

enum _Tone { neutral, success, error }
