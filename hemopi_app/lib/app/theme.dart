import 'package:flutter/material.dart';

class AppTheme {
  // Professional Clinical Color Palette
  static const Color primaryTeal = Color(0xFF007A78); // Calming, scientific medical teal
  static const Color primaryTealDark = Color(0xFF005654);
  static const Color primaryTealLight = Color(0xFFE0F2F1);

  static const Color accentNavy = Color(0xFF1E3A5F); // Trustworthy medical slate navy
  static const Color surfaceWarmWhite = Color(0xFFF9FBFC); // Clean clinical background
  static const Color cardSurface = Colors.white;

  // Semantics
  static const Color statusReady = Color(0xFF0D8A58); // Forest Green
  static const Color statusReadyBg = Color(0xFFE8F5E9);
  static const Color statusAttention = Color(0xFFD97706); // Warm Amber
  static const Color statusAttentionBg = Color(0xFFFEF3C7);
  static const Color statusError = Color(0xFFDC2626); // Crimson
  static const Color statusErrorBg = Color(0xFFFEE2E2);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTeal,
        primary: primaryTeal,
        onPrimary: Colors.white,
        primaryContainer: primaryTealLight,
        onPrimaryContainer: primaryTealDark,
        secondary: accentNavy,
        surface: surfaceWarmWhite,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: surfaceWarmWhite,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1E293B)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryTeal,
          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryTeal, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 4,
        indicatorColor: primaryTealLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: primaryTealDark,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            );
          }
          return const TextStyle(color: Color(0xFF64748B), fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryTealDark, size: 24);
          }
          return const IconThemeData(color: Color(0xFF64748B), size: 24);
        }),
      ),
    );
  }
}
