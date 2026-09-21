/// Spacing and corner-radius scale. Use these instead of magic numbers so the
/// whole app shares one rhythm.
///
/// Radius rule: `radiusSm` chips, `radiusMd` inputs/buttons, `radiusLg` cards,
/// `radiusXl` sheets/large surfaces, `radiusFull` pills.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Horizontal page gutter used by every screen.
  static const double page = 16;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;
}
