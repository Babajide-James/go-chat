import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand Palette ──────────────────────────────────────────────────────────
  /// Primary action: High-energy orange for Send buttons, active states.
  static const Color primaryOrange = Color(0xFFFF4F00); // International Orange

  /// Warm secondary: Burnt Sienna for borders, secondary actions.
  static const Color darkOrange = Color(0xFFE97451); // Burnt Sienna

  /// Subtle tint: Seashell for backgrounds, input fills, chat bubbles.
  static const Color lightPeach = Color(0xFFFFF5EE); // Seashell

  /// Same as lightPeach but alias used as scaffold background.
  static const Color softWhite = Color(0xFFFFF5EE); // Seashell

  /// Deep accent: Rust for text, icon labels, contrast elements.
  static const Color textDark = Color(0xFFA0522D); // Rust

  /// Muted rust for hint text / subtitles.
  static const Color textLight = Color(0xFFC07A50);

  // ── Theme ──────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: softWhite,
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: darkOrange,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: Color(0x55FF4F00),
          minimumSize: Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkOrange,
          textStyle: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFFE97451), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
        labelStyle: const TextStyle(color: textLight),
        hintStyle: const TextStyle(color: textLight),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        iconColor: primaryOrange,
      ),
    );
  }
}
