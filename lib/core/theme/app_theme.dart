import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const page = 20.0;
}

abstract final class AppTheme {
  /// Tests turn this off to avoid network font fetching.
  static bool useGoogleFonts = true;

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppPalette.indigo,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE3E7FF),
          onPrimaryContainer: AppPalette.indigoDeep,
          secondary: AppPalette.gold,
          onSecondary: AppPalette.ink,
          secondaryContainer: Color(0xFFFFF1CC),
          onSecondaryContainer: Color(0xFF5C3F00),
          tertiary: AppPalette.saffron,
          onTertiary: Colors.white,
          error: AppPalette.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: AppPalette.ink,
          surfaceContainerLowest: AppPalette.parchment,
          surfaceContainerLow: Color(0xFFF5F1E7),
          surfaceContainer: Color(0xFFF0ECE2),
          surfaceContainerHigh: Color(0xFFEAE5D9),
          onSurfaceVariant: AppPalette.inkSecondary,
          outline: Color(0xFFD6D0C2),
          outlineVariant: Color(0xFFE9E4D8),
        ),
        extension: NyayaColors.light,
        scaffold: AppPalette.parchment,
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppPalette.darkPrimary,
          onPrimary: AppPalette.indigoDeep,
          primaryContainer: Color(0xFF26338F),
          onPrimaryContainer: Color(0xFFE3E7FF),
          secondary: AppPalette.gold,
          onSecondary: AppPalette.ink,
          secondaryContainer: Color(0xFF4A3600),
          onSecondaryContainer: Color(0xFFFFE08A),
          tertiary: AppPalette.saffron,
          onTertiary: Colors.white,
          error: AppPalette.darkError,
          onError: AppPalette.ink,
          surface: AppPalette.darkSurface,
          onSurface: AppPalette.darkText,
          surfaceContainerLowest: AppPalette.darkBg,
          surfaceContainerLow: Color(0xFF111735),
          surfaceContainer: AppPalette.darkSurface,
          surfaceContainerHigh: AppPalette.darkSurfaceHigh,
          onSurfaceVariant: AppPalette.darkTextSecondary,
          outline: Color(0xFF3A4370),
          outlineVariant: Color(0xFF26305C),
        ),
        extension: NyayaColors.dark,
        scaffold: AppPalette.darkBg,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required NyayaColors extension,
    required Color scaffold,
  }) {
    final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
    final body = useGoogleFonts ? GoogleFonts.plusJakartaSansTextTheme(base.textTheme) : base.textTheme;
    final display = useGoogleFonts ? GoogleFonts.dmSerifDisplayTextTheme(base.textTheme) : base.textTheme;
    final textTheme = body
        .copyWith(
          displayLarge: display.displayLarge,
          displayMedium: display.displayMedium,
          displaySmall: display.displaySmall,
          headlineLarge: display.headlineLarge,
          headlineMedium: body.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          headlineSmall: body.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      textTheme: textTheme,
      extensions: [extension],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: extension.cardBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          side: BorderSide(color: scheme.outline, width: 1.5),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: extension.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: extension.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        side: BorderSide(color: extension.cardBorder),
        labelStyle: textTheme.labelLarge?.copyWith(fontSize: 13),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelSmall?.copyWith(
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
      dividerTheme: DividerThemeData(color: extension.cardBorder, thickness: 1),
    );
  }
}
