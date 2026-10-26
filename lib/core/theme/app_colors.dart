import 'package:material_ui/material_ui.dart';

/// "Terracotta × Sand" palette — warm, editorial, premium, trustworthy.
/// Contrast ratios are documented in docs/DESIGN.md. Rules:
/// - Usage mix: ~60% Warm Cream, ~20% Sand / light neutral surfaces,
///   ~15% Terracotta, ~5% Burnt Clay accents.
/// - Deep Earth is the text colour everywhere on light surfaces.
/// - No purple, neon, metallic effects or decorative gradients: fills are flat.
/// - Ochre is reserved for XP, stars, crowns and premium fills — use [ochreText]
///   when it has to be text on a light surface.
/// - Success/error are muted earth tones, always paired with an icon or label.
abstract final class AppPalette {
  // ── Brand ─────────────────────────────────────────────────────────────────
  /// Primary brand, buttons, active navigation.
  static const terracotta = Color(0xFF873F2B);
  static const terracottaDeep = Color(0xFF5E2A1C);

  /// Secondary accents and highlights (streak flame, combos).
  static const burntClay = Color(0xFFB96243);

  /// Borders, subtle surfaces, supporting elements.
  static const sand = Color(0xFFD9B994);
  static const sandLight = Color(0xFFEADBC6);

  /// Main background and light surfaces.
  static const cream = Color(0xFFF5EBDD);
  static const creamLight = Color(0xFFFBF6EF);

  /// Headings, body text, primary typography.
  static const deepEarth = Color(0xFF302923);
  static const earthSecondary = Color(0xFF6B5B4E);

  // ── Functional (earth-toned) ──────────────────────────────────────────────
  static const ochre = Color(0xFFC28A2C);
  static const ochreSoft = Color(0xFFE8C98A);
  static const ochreText = Color(0xFF8A5A12);
  static const moss = Color(0xFF4D6B35);
  static const mossLight = Color(0xFF7A9A5A);
  static const brick = Color(0xFFB42318);
  static const frost = Color(0xFF7F9C9A);

  /// Flat category colours (chapters, modes, avatars). All carry white text.
  static const umber = Color(0xFF5C4433);
  static const ochreDeep = Color(0xFF946A1E);
  static const slate = Color(0xFF4F5D5A);

  // ── Dark theme (derived from Deep Earth) ──────────────────────────────────
  static const darkBg = Color(0xFF1C1713);
  static const darkSurface = Color(0xFF26201B);
  static const darkSurfaceHigh = Color(0xFF322A23);
  static const darkText = cream;
  static const darkTextSecondary = Color(0xFFC4B3A0);
  static const darkPrimary = Color(0xFFD98B6A);
  static const darkSuccess = Color(0xFF9DBB7A);
  static const darkError = Color(0xFFF08A7E);
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
    required this.hero,
  });

  /// Reward fill (XP, stars, crowns, premium).
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

  /// Solid fill for hero cards and brand badges.
  final Color hero;

  static const light = NyayaColors(
    gold: AppPalette.ochre,
    streak: AppPalette.burntClay,
    energy: AppPalette.ochre,
    success: AppPalette.moss,
    successContainer: Color(0xFFE3EAD3),
    error: AppPalette.brick,
    errorContainer: Color(0xFFF6DCD5),
    textSecondary: AppPalette.earthSecondary,
    cardBorder: AppPalette.sandLight,
    locked: Color(0xFFCDBFAE),
    hero: AppPalette.terracotta,
  );

  static const dark = NyayaColors(
    gold: AppPalette.ochre,
    streak: AppPalette.burntClay,
    energy: AppPalette.ochre,
    success: AppPalette.darkSuccess,
    successContainer: Color(0xFF2A3320),
    error: AppPalette.darkError,
    errorContainer: Color(0xFF3F1F1A),
    textSecondary: AppPalette.darkTextSecondary,
    cardBorder: Color(0xFF3A3029),
    locked: Color(0xFF4A3F36),
    hero: Color(0xFF6E3323),
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
      hero: l(hero, other.hero),
    );
  }
}

extension NyayaThemeX on BuildContext {
  NyayaColors get nyaya => Theme.of(this).extension<NyayaColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
