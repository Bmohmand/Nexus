import 'package:flutter/material.dart';

/// Manifest brand colors — slate/emerald tactical palette.
class ManifestColors {
  ManifestColors._();

  static const Color primary = Color(0xFF10B981);      // Emerald-500
  static const Color primaryDark = Color(0xFF059669);   // Emerald-600
  static const Color surface = Color(0xFF0F172A);       // Slate-900
  static const Color surfaceLight = Color(0xFF1E293B);  // Slate-800
  static const Color accent = Color(0xFF38BDF8);        // Sky-400
  static const Color warning = Color(0xFFFBBF24);       // Amber-400
  static const Color error = Color(0xFFEF4444);         // Red-500
  static const Color textPrimary = Color(0xFFF8FAFC);   // Slate-50
  static const Color textSecondary = Color(0xFF94A3B8);  // Slate-400
}

/// Light theme
ThemeData manifestLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: ManifestColors.primary,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
    ),
  );
}

/// Dark theme (primary — Manifest is dark-first)
ThemeData manifestDarkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: ManifestColors.primary,
      brightness: Brightness.dark,
      surface: ManifestColors.surface,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: ManifestColors.surface,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: ManifestColors.surface,
    ),
    cardTheme: CardThemeData(
      color: ManifestColors.surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ManifestColors.surface,
      indicatorColor: ManifestColors.primary.withValues(alpha: 0.2),
    ),
  );
}
