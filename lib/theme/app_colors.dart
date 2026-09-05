import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand palette - Midnight & Electric
  static const Color midnight = Color(0xFF0A0E1A);
  static const Color electricBlue = Color(0xFF4D9FFF);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color periwinkle = Color(0xFF8B9CFF);

  // Primary - electric blue
  static const Color primary = Color(0xFF4D9FFF);
  static const Color primaryDark = Color(0xFF1E5FD6);
  static const Color primaryLight = Color(0xFF14223B);
  static const Color primaryMedium = Color(0xFF77B4FF);

  // Secondary - cyan
  static const Color secondary = Color(0xFF22D3EE);
  static const Color secondaryLight = Color(0xFF122733);

  // Surface & Background (midnight)
  static const Color surface = Color(0xFF12182B);
  static const Color background = Color(0xFF0A0E1A);
  static const Color cardBorder = Color(0xFF2A3554);

  // Text
  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFFA9B4D4);
  static const Color textHint = Color(0xFF6C769B);

  // Status
  static const Color error = Color(0xFFFF7C93);
  static const Color errorLight = Color(0xFF3A1B26);
  static const Color success = Color(0xFF3DDC97);
  static const Color successLight = Color(0xFF122A20);
  static const Color warning = Color(0xFFFFB454);
  static const Color warningLight = Color(0xFF33271A);

  // Feature accents
  static const Color blue = Color(0xFF4D9FFF);
  static const Color green = Color(0xFF3DDC97);
  static const Color orange = Color(0xFFFFB454);
  static const Color purple = Color(0xFF8B9CFF);
  static const Color pink = Color(0xFFF472B6);

  // Glass - very light frost: small blur, dark translucent tint (no white wash)
  static const double glassOpacity = 0.5;
  static const double glassBlur = 5;
  static const Color glassTint = Color(0xFF1D2642);
}