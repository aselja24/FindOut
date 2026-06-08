import 'package:flutter/material.dart';

class AppTextStyles {
  AppTextStyles._();
  static const String _fontFamily = 'Poppins';

  static const TextStyle h1 = TextStyle(fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.w700, height: 1.3);
  static const TextStyle h2 = TextStyle(fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static const TextStyle h3 = TextStyle(fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4);
  static const TextStyle h4 = TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);
  static const TextStyle body = TextStyle(fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w400, height: 1.6);
  static const TextStyle bodyMedium = TextStyle(fontFamily: _fontFamily, fontSize: 15, fontWeight: FontWeight.w500, height: 1.6);
  static const TextStyle caption = TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w400, height: 1.5);
  static const TextStyle captionMedium = TextStyle(fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500, height: 1.5);
  static const TextStyle button = TextStyle(fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3);
  static const TextStyle label = TextStyle(fontFamily: _fontFamily, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4);
  static const TextStyle wordCard = TextStyle(fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.w700);
  static const TextStyle levelBadge = TextStyle(fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);
}

// Extension for missing styles
extension AppTextStylesExt on AppTextStyles {
  static TextStyle get labelBold => const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, height: 1.4);
}
