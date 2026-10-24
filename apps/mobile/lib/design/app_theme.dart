import 'package:flutter/material.dart';

/// Shared visual language for the landscape workspace.
class AppTheme {
  static const background = Color(0xFF0C121C);
  static const surface = Color(0xFF151E2B);
  static const border = Color(0xFF293447);
  static const gold = Color(0xFFE2C48D);
  static const muted = Color(0xFFA6B2C5);
  static const ink = Color(0xFFF2F4F7);

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
    ).copyWith(
      primary: gold,
      onPrimary: background,
      secondary: const Color(0xFF81C7BA),
      onSecondary: background,
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: border,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme,
      fontFamily: 'Noto Sans CJK SC',
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei', 'sans-serif'],
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600, letterSpacing: .4),
        titleLarge: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: const TextStyle(fontSize: 14, height: 1.6),
        bodySmall: const TextStyle(fontSize: 12, height: 1.5, color: muted),
      ),
      cardTheme: CardTheme(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Color(0xFF101824),
        indicatorColor: Color(0xFF343229),
        selectedIconTheme: IconThemeData(color: gold, size: 23),
        unselectedIconTheme: IconThemeData(color: muted, size: 23),
        selectedLabelTextStyle: TextStyle(color: gold, fontWeight: FontWeight.w600),
        unselectedLabelTextStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: const Color(0xFF343229),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        iconColor: gold,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 1),
    );
  }
}
