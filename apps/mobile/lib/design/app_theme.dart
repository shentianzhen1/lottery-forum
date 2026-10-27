import 'package:flutter/material.dart';

/// Shared visual language for the landscape-first client.
///
/// Keep the theme on platform/system fonts. The app previously relied on a
/// non-bundled CJK family in previews, which made glyph fallback harder to
/// reason about. Popular-play identity also uses text badges instead of icon
/// font glyphs, so the cards remain stable across Android/CI renderers.
class AppTheme {
  static const background = Color(0xFF091525);
  static const rail = Color(0xFF0E1E33);
  static const surface = Color(0xFF142942);
  static const surfaceSoft = Color(0xFF1A3552);
  static const surfaceRaised = Color(0xFF203C5B);
  static const border = Color(0xFF2A4868);
  static const borderStrong = Color(0xFF3B6085);
  static const blue = Color(0xFF91BFF0);
  static const gold = Color(0xFFE3C58C);
  static const teal = Color(0xFF83C9BC);
  static const muted = Color(0xFFA7B3C4);
  static const ink = Color(0xFFF4F6F8);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: blue,
      onPrimary: background,
      secondary: teal,
      onSecondary: background,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: border,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      splashColor: blue.withOpacity(.08),
      hoverColor: blue.withOpacity(.06),
      highlightColor: Colors.transparent,
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
        ),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
        bodySmall: const TextStyle(fontSize: 12, height: 1.45, color: muted),
      ),
      cardTheme: CardTheme(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: rail,
        indicatorColor: Color(0xFF203E60),
        selectedIconTheme: IconThemeData(color: blue, size: 22),
        unselectedIconTheme: IconThemeData(color: muted, size: 22),
        selectedLabelTextStyle: TextStyle(color: blue, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          foregroundColor: background,
          backgroundColor: blue,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF10233A),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: const Color(0xFF203E60),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(color: ink),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        iconColor: gold,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    );
  }
}
