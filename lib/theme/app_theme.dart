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
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      // Apply Orbitron globally
      textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: Colors.white,
        displayColor: accent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, // Transparent for overlay feel? Or surface.
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.orbitron(
          color: accent,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
        iconTheme: const IconThemeData(color: accent),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          shape: const BeveledRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4))),
          textStyle: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
          // Suppress the OS "touch sound" so only the game's own SFX play
          // (and stay under the in-game mute). See also listTile/bottomNav.
          enableFeedback: false,
        ),
      ),

      // Additional standard buttons alignment
      textButtonTheme: TextButtonThemeData(
         style: TextButton.styleFrom(
            textStyle: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
            enableFeedback: false,
         ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(enableFeedback: false),
      ),

      listTileTheme: const ListTileThemeData(enableFeedback: false),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        enableFeedback: false,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        enableFeedback: false,
        shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
    );
  }
}
