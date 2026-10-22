import 'package:material_ui/material_ui.dart';

/// "Nyaya Indigo + Saffron Gold" palette. Contrast ratios are documented in
/// docs/DESIGN.md. Rules:
/// - Gold is reserved for XP, stars, crowns and premium — never as text on light.
/// - Saffron/orange is for energy and the streak flame.
/// - Error red is brief and always paired with an explanation.
abstract final class AppPalette {
  static const indigo = Color(0xFF1E2A78);
  static const indigoDeep = Color(0xFF141C55);
  static const indigoSoft = Color(0xFF3B4BB0);
  static const gold = Color(0xFFF2A900);
  static const goldSoft = Color(0xFFFFD66B);
  static const saffron = Color(0xFFFF7A1A);
  static const green = Color(0xFF15803D);
  static const greenBright = Color(0xFF22C55E);
  static const red = Color(0xFFC62828);
  static const amberText = Color(0xFFB45309);
  static const amber = Color(0xFFF59E0B);
  static const parchment = Color(0xFFFAF7F0);
  static const ink = Color(0xFF14182B);
  static const inkSecondary = Color(0xFF5A6178);

  static const darkBg = Color(0xFF0B1026);
  static const darkSurface = Color(0xFF151C3B);
  static const darkSurfaceHigh = Color(0xFF1E2750);
  static const darkText = Color(0xFFEEF0F7);
  static const darkTextSecondary = Color(0xFFA7AEC6);
  static const darkPrimary = Color(0xFF8C9EFF);
  static const darkSuccess = Color(0xFF4ADE80);
  static const darkError = Color(0xFFF87171);
}

/// Semantic colors not covered by [ColorScheme], exposed as a theme extension
/// so light/dark variants switch automatically.
@immutable
class NyayaColors extends ThemeExtension<NyayaColors> {
  const NyayaColors({
    required this.gold,
    required this.streak,
    required this.energy,
    required this.success,
    required this.successContainer,
    required this.error,
    required this.errorContainer,
    required this.textSecondary,
    required this.cardBorder,
    required this.locked,
    required this.heroGradient,
  });

  final Color gold;
  final Color streak;
  final Color energy;
  final Color success;
  final Color successContainer;
  final Color error;
  final Color errorContainer;
  final Color textSecondary;
  final Color cardBorder;
  final Color locked;
  final List<Color> heroGradient;

  static const light = NyayaColors(
    gold: AppPalette.gold,
    streak: AppPalette.saffron,
    energy: AppPalette.amber,
    success: AppPalette.green,
    successContainer: Color(0xFFDCFCE7),
    error: AppPalette.red,
    errorContainer: Color(0xFFFEE2E2),
    textSecondary: AppPalette.inkSecondary,
    cardBorder: Color(0xFFE9E4D8),
    locked: Color(0xFFC9CCD6),
    heroGradient: [AppPalette.indigo, AppPalette.indigoSoft],
  );

  static const dark = NyayaColors(
    gold: AppPalette.gold,
    streak: AppPalette.saffron,
    energy: AppPalette.amber,
    success: AppPalette.darkSuccess,
    successContainer: Color(0xFF12351F),
    error: AppPalette.darkError,
    errorContainer: Color(0xFF3B1518),
    textSecondary: AppPalette.darkTextSecondary,
    cardBorder: Color(0xFF26305C),
    locked: Color(0xFF3A4266),
    heroGradient: [Color(0xFF26338F), Color(0xFF1A2160)],
  );

  @override
  NyayaColors copyWith() => this;

  @override
  NyayaColors lerp(ThemeExtension<NyayaColors>? other, double t) {
    if (other is! NyayaColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return NyayaColors(
      gold: l(gold, other.gold),
      streak: l(streak, other.streak),
      energy: l(energy, other.energy),
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      error: l(error, other.error),
      errorContainer: l(errorContainer, other.errorContainer),
      textSecondary: l(textSecondary, other.textSecondary),
      cardBorder: l(cardBorder, other.cardBorder),
      locked: l(locked, other.locked),
      heroGradient: [
        l(heroGradient[0], other.heroGradient[0]),
        l(heroGradient[1], other.heroGradient[1]),
      ],
    );
  }
}

extension NyayaThemeX on BuildContext {
  NyayaColors get nyaya => Theme.of(this).extension<NyayaColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
