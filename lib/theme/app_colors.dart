import 'package:flutter/material.dart';

/// The palette: near-black surfaces, soft indigo as the accent, and a muted
/// gold kept for the numbers that matter most (CGPA, a finished result).
class AppColors {
  AppColors._();

  // Base
  static const Color midnight = Color(0xFF05060B);
  static const Color background = Color(0xFF05060B);
  static const Color backgroundTop = Color(0xFF0B0E1C);
  static const Color surface = Color(0xFF0D1020);
  static const Color surfaceRaised = Color(0xFF141831);
  static const Color cardBorder = Color(0xFF1D2338);

  // Accent
  static const Color electricBlue = Color(0xFF7B93FF);
  static const Color cyan = Color(0xFF5AD8E6);
  static const Color periwinkle = Color(0xFFA08BFF);
  static const Color gold = Color(0xFFE6C47A);

  static const Color primary = Color(0xFF7B93FF);
  static const Color primaryDark = Color(0xFF3A4BC4);
  static const Color primaryLight = Color(0xFF141A33);
  static const Color primaryMedium = Color(0xFFA3B3FF);

  static const Color secondary = Color(0xFF5AD8E6);
  static const Color secondaryLight = Color(0xFF0F2429);

  // Text
  static const Color textPrimary = Color(0xFFEEF1FA);
  static const Color textSecondary = Color(0xFF9AA3BD);
  static const Color textHint = Color(0xFF5F6884);

  // Status
  static const Color error = Color(0xFFFF6B81);
  static const Color errorLight = Color(0xFF2E1219);
  static const Color success = Color(0xFF4FD69C);
  static const Color successLight = Color(0xFF0F241B);
  static const Color warning = Color(0xFFF5B94F);
  static const Color warningLight = Color(0xFF2B2112);

  // Feature accents
  static const Color blue = Color(0xFF7B93FF);
  static const Color green = Color(0xFF4FD69C);
  static const Color orange = Color(0xFFF5A04F);
  static const Color purple = Color(0xFFA08BFF);
  static const Color pink = Color(0xFFF27FB2);

  // Glass. Cards are a translucent tint with a hairline edge. Real blur is
  // reserved for the few surfaces that float over content (nav bar, sheets).
  static const double glassOpacity = 0.62;
  static const double glassBlur = 14;
  static const Color glassTint = Color(0xFF0E1224);
  static const Color hairline = Color(0x14FFFFFF);
}
