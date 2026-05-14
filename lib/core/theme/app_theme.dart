import 'package:flutter/material.dart';

class AppTheme {
  // Romantic Orange Palette
  static const Color primaryOrange = Color(0xFFFF7E67); // Sunset orange
  static const Color lightPeach = Color(0xFFFFD1C1);
  static const Color darkOrange = Color(0xFFE25B45);
  static const Color softWhite = Color(0xFFFFF9F7);
  static const Color textDark = Color(0xFF4A3F3D);
  static const Color textLight = Color(0xFF8B7E7C);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: softWhite,
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: darkOrange,
        surface: Colors.white,
        background: softWhite,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDark,
        onBackground: textDark,
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
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkOrange,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: lightPeach.withOpacity(0.5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
        labelStyle: const TextStyle(color: textLight),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        iconColor: primaryOrange,
      ),
    );
  }
}
