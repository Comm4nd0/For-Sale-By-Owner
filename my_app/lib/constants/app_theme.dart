import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Primary - Cyan palette
  static const Color forestDeep = Color(0xFF115E66);   // Dark cyan deep
  static const Color forestMid = Color(0xFF19747E);    // Dark Cyan #19747E
  static const Color forestLight = Color(0xFF2A9DA8);  // Lighter cyan
  static const Color forestMist = Color(0xFFD1E8E2);   // Soft Mint Green #D1E8E2

  // Accent - Cyan palette
  static const Color goldEmber = Color(0xFF19747E);    // Dark Cyan accent
  static const Color goldWarm = Color(0xFF2A9DA8);     // Lighter cyan accent
  static const Color goldSoft = Color(0xFFA9D6E5);     // Light Blue #A9D6E5

  // Neutrals
  static const Color charcoal = Color(0xFF1A2C33);
  static const Color slate = Color(0xFF4A5C62);
  static const Color stone = Color(0xFF8FA3A8);
  static const Color pebble = Color(0xFFE2E2E2);      // Platinum #E2E2E2
  static const Color cream = Color(0xFFF5F8F9);
  static const Color white = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF19747E);
  static const Color warning = Color(0xFFC9872A);
  static const Color error = Color(0xFFB03A2E);
  static const Color info = Color(0xFF1B6CA8);

  // Legacy aliases
  static const Color primaryColor = forestDeep;
  static const Color secondaryColor = forestMid;
  static const Color backgroundColor = cream;
  static const Color surfaceColor = white;
  static const Color textPrimary = charcoal;
  static const Color textSecondary = slate;

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    textTheme: GoogleFonts.nunitoTextTheme(),
    colorScheme: ColorScheme.fromSeed(
      seedColor: forestDeep,
      primary: forestDeep,
      secondary: forestMid,
      tertiary: goldEmber,
      surface: white,
      error: error,
    ),
    scaffoldBackgroundColor: cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: forestDeep,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: white,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: forestMid,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: forestMid,
        side: const BorderSide(color: forestMid),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: forestMid,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: forestMid,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: pebble),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: forestMid, width: 2),
      ),
    ),
    dividerColor: pebble,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: forestDeep,
    ),
  );
}
