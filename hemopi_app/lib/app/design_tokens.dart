import 'package:flutter/material.dart';

/// Clinical design tokens for HemoPi medical user interface.
class AppColors {
  AppColors._();

  // Primary Clinical Palette
  static const Color primary = Color(0xFF007A78); // Calming, scientific medical teal
  static const Color primaryDark = Color(0xFF005654);
  static const Color primaryLight = Color(0xFFE0F2F1);
  static const Color primaryContainer = Color(0xFFE6F4F3);

  // Secondary & Accents
  static const Color navy = Color(0xFF1E3A5F); // Trustworthy medical slate navy
  static const Color navyLight = Color(0xFFEDF2F7);

  // Surfaces & Backgrounds
  static const Color background = Color(0xFFF8FAFC); // Clean clinical warm white
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = Color(0xFFF1F5F9);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderFocus = Color(0xFF007A78);

  // Typography Colors
  static const Color textPrimary = Color(0xFF0F172A); // High-contrast slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textDisabled = Color(0xFF94A3B8); // Slate 400

  // Semantic Status Colors
  static const Color statusSuccess = Color(0xFF0D8A58); // Forest Green
  static const Color statusSuccessBg = Color(0xFFE8F5E9);
  static const Color statusSuccessBorder = Color(0xFFC8E6C9);

  static const Color statusWarning = Color(0xFFD97706); // Warm Amber
  static const Color statusWarningBg = Color(0xFFFEF3C7);
  static const Color statusWarningBorder = Color(0xFFFDE68A);

  static const Color statusError = Color(0xFFDC2626); // Crimson
  static const Color statusErrorBg = Color(0xFFFEE2E2);
  static const Color statusErrorBorder = Color(0xFFFECACA);

  static const Color statusInfo = Color(0xFF0284C7); // Sky Blue
  static const Color statusInfoBg = Color(0xFFE0F2FE);
  static const Color statusInfoBorder = Color(0xFFBAE6FD);
}

class AppSpacing {
  AppSpacing._();

  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
}

class AppRadii {
  AppRadii._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double full = 999.0;
}
