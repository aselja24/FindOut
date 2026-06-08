import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary (Purple)
  static const Color primary = Color(0xFF7643EE);
  static const Color primaryLight = Color(0xFFBAA1F6);

  // Accent (Lime)
  static const Color accent = Color(0xFFB7E92A);
  static const Color accentLight = Color(0xFFDBF494);

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color backgroundGrey = Color(0xFFF1F1F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F1F1);

  // Text & Grayscale
  static const Color textPrimary = Color(0xFF252525);
  static const Color textSecondary = Color(0xFF5F5F5F);
  static const Color textMuted = Color(0xFF5F5F5F);
  static const Color black = Color(0xFF000000);

  // Aliases for compatibility
  static const Color onSurface = Color(0xFF252525);
  static const Color onSurfaceMuted = Color(0xFF5F5F5F);

  // Border
  static const Color border = Color(0xFFF1F1F1);
  static const Color borderSelected = Color(0xFF7643EE);

  // Semantic & Decorative
  static const Color success = Color(0xFFB7E92A);
  static const Color error = Color(0xFFE9502A);
  static const Color warning = Color(0xFFFF7B33);

  // Decorative Palette from design
  static const Color pink = Color(0xFFFD65BD);
  static const Color pinkLight = Color(0xFFFFA5D9);
  static const Color orange = Color(0xFFFF7B33);
  static const Color orangeLight = Color(0xFFFD9E6B);

  // Functional mappings (Compatibility)
  static const Color secondary = Color(0xFFFD65BD);
  static const Color info = Color(0xFFBAA1F6);
}
