import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color background = Color(0xFF1A1D21); // Dark Slate
  static const Color surface = Color(0xFF2B2F33); // Lighter Slate
  static const Color accent = Color(0xFFFFB700); // Bitcoin Amber
  static const Color textPrimary = Color(0xFFECEFF1);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color border = Colors.black;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.dark(
        primary: accent,
        surface: surface,
        // background: background, // Deprecated, surface is enough or use onSurface
      ),
      textTheme: GoogleFonts.orbitronTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: accent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: accent,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4), // Slightly angular
            side: const BorderSide(color: border, width: 2),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: border, width: 2),
        ),
      ),
    );
  }
}
