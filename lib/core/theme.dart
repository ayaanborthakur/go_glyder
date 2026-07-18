import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Bundled modern typeface (see pubspec `fonts:`). Applied app-wide via the
/// text theme so every screen lifts off Flutter's default Roboto.
const String kFontFamily = 'PlusJakartaSans';

/// Central design system for GoGlyder.
///
/// Everything visual — colors, corner radii, spacing, and the app-wide
/// [ThemeData] — lives here so screens stay consistent instead of each
/// redefining their own greens and paddings.
class AppColors {
  AppColors._();

  // Brand greens
  static const Color brandDark = Color(0xFF023020); // primary brand
  static const Color brandGreen = Color(0xFF0A5C36); // mid
  static const Color brandAccent = Color(0xFF2FBF71); // bright accent
  static const Color brandTint = Color(0xFFE7F3EC); // pale green fill

  // Neutrals / surfaces
  static const Color background = Color(0xFFF3F5F4); // app background
  static const Color surface = Colors.white; // cards, sheets
  static const Color divider = Color(0xFFE6EAE8);

  // Text
  static const Color textPrimary = Color(0xFF12211A);
  static const Color textSecondary = Color(0xFF667471);
  static const Color textTertiary = Color(0xFF9AA6A1);

  // Status
  static const Color danger = Color(0xFFE5484D);
  static const Color success = Color(0xFF2FBF71);
  static const Color accentOrange = Color(0xFFF59E0B);
}

/// Shared corner radii — keeps every card/button on the same rounding scale.
class AppRadius {
  AppRadius._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

/// Consistent spacing scale.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard page gutter.
  static const EdgeInsets page = EdgeInsets.symmetric(horizontal: 20);
}

/// Soft, iOS-style card shadow used across the app.
const List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: Color(0x14000000), // ~8% black
    blurRadius: 18,
    offset: Offset(0, 8),
  ),
];

/// A cover gradient per group category — gives each group card/header a
/// distinct visual identity instead of a plain icon on a flat background.
/// Falls back to the brand green for an unrecognized/empty category key.
LinearGradient groupCoverGradient(String? category) {
  const gradients = {
    'morning': [Color(0xFFB45309), Color(0xFFFBBF24)], // sunrise amber
    'afterschool': [Color(0xFF0E7490), Color(0xFF22D3EE)], // afternoon teal
    'sports': [Color(0xFF1D4ED8), Color(0xFF60A5FA)], // energetic blue
    'music': [Color(0xFF6D28D9), Color(0xFFC084FC)], // creative violet
    'events': [Color(0xFF9D174D), Color(0xFFF472B6)], // festive pink
    'general': [Color(0xFF0A5C36), Color(0xFF2FBF71)], // brand green
  };
  final colors = gradients[category] ?? gradients['general']!;
  return LinearGradient(
    colors: colors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brandDark,
      primary: AppColors.brandDark,
      secondary: AppColors.brandAccent,
      surface: AppColors.surface,
      brightness: Brightness.light,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: kFontFamily,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      // iOS-style smooth slide transitions on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.brandDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: kFontFamily,
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandDark,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontFamily: kFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.brandGreen),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.brandDark,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        showUnselectedLabels: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    // Plus Jakarta Sans (bundled) — a modern geometric sans that reads as
    // premium and instantly lifts every screen off Flutter's default Roboto.
    return base
        .copyWith(
          headlineLarge: base.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
          headlineMedium: base.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.4),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(
          fontFamily: kFontFamily,
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );
  }
}
