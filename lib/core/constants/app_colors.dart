import 'package:flutter/material.dart';

/// Premium Fintech Design System Palette for KharchaAI
class AppColors {
  // Brand Primary & Accents
  static const Color primary = Color(0xFF4568F5);          // Primary Blue
  static const Color primaryLight = Color(0xFF708BFA);     // Lighter Blue Accent
  static const Color primaryDark = Color(0xFF2E4EC7);      // Darker Blue
  static const Color primarySurface = Color(0xFFEEF2FF);   // Soft Blue Surface
  static const Color secondary = Color(0xFF101828);        // Deep Navy

  // Deep Navy Spectrum
  static const Color deepNavy = Color(0xFF101828);
  static const Color navyMedium = Color(0xFF1D2939);
  static const Color navyLight = Color(0xFF344054);

  // Background & Surfaces (Light Mode)
  static const Color background = Color(0xFFF7F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE4E7EC);
  static const Color border = Color(0xFFE4E7EC);

  // Dark Mode Tokens
  static const Color darkBackground = Color(0xFF0C111D);
  static const Color darkSurface = Color(0xFF161F30);
  static const Color darkCardBorder = Color(0xFF243049);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
  static const Color darkPrimarySurface = Color(0xFF1E284A);

  // Text Hierarchy (Light Mode)
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF98A2B3);

  // Semantic Status Colors
  static const Color success = Color(0xFF16A36A);
  static const Color successBg = Color(0xFFECFDF3);
  static const Color error = Color(0xFFE05252);
  static const Color errorBg = Color(0xFFFEF3F2);
  static const Color errorSurface = Color(0xFFFEF3F2);
  static const Color warning = Color(0xFFF5A623);
  static const Color warningBg = Color(0xFFFFFBEB);

  // Fintech Accents & Gradients
  static const Color purpleAccent = Color(0xFF7C3AED);
  static const Color purpleBg = Color(0xFFF4F0FF);
  static const Color cyanAccent = Color(0xFF0891B2);
  static const Color cyanBg = Color(0xFFECFEFF);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF4568F5), Color(0xFF2A4EDB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient navyHeroGradient = LinearGradient(
    colors: [Color(0xFF101828), Color(0xFF1D2939)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlowGradient = LinearGradient(
    colors: [Color(0xFF4568F5), Color(0xFF6366F1), Color(0xFF0E7490)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
