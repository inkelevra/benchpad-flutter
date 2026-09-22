import 'package:flutter/material.dart';

/// BenchPad visual theme.
///
/// The PWA uses a dark UI with an amber/orange accent (visible in
/// advertise.html's buttons and highlight states). Centralizing it here
/// so every screen we port stays visually consistent — and so a single
/// change here (e.g. accent color) propagates everywhere, unlike the PWA
/// where colors were repeated inline in each HTML file's <style> block.
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF17171A);
  static const Color surfaceElevated = Color(0xFF212124);
  static const Color accent = Color(0xFFE8A33D);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF9A9A9E);
  static const Color danger = Color(0xFFE05252);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        error: danger,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFFD8D8DC),
          disabledForegroundColor: const Color(0xFF6B6B70),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: const Color(0xFF6B6B70),
          foregroundColor: textPrimary,
          side: const BorderSide(color: Color(0xFF3A3A3E)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
