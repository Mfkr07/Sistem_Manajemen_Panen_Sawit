import 'package:flutter/material.dart';

/// Shared accent colors — identical in light & dark themes.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF34D399);
  static const Color primaryDark = Color(0xFF10B981);
  static const Color primaryLight = Color(0xFF6EE7B7);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetLight = Color(0xFFA78BFA);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberLight = Color(0xFFFBBF24);
  static const Color rose = Color(0xFFF43F5E);
  static const Color blue = Color(0xFF3B82F6);

  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF06B6D4)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientViolet = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientAmber = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientRose = LinearGradient(
    colors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

/// Theme-dependent surface / text / border colors.
class DColors {
  final Color bg;
  final Color surface;
  final Color surfaceLight;
  final Color surfaceBright;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderLight;

  const DColors({
    required this.bg, required this.surface,
    required this.surfaceLight, required this.surfaceBright,
    required this.textPrimary, required this.textSecondary,
    required this.textMuted, required this.border, required this.borderLight,
  });

  static const dark = DColors(
    bg: Color(0xFF0B0F19),
    surface: Color(0xFF141925),
    surfaceLight: Color(0xFF1C2333),
    surfaceBright: Color(0xFF232B3E),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    border: Color(0x14FFFFFF),
    borderLight: Color(0x1FFFFFFF),
  );

  static const light = DColors(
    bg: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceLight: Color(0xFFF1F5F9),
    surfaceBright: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFFE2E8F0),
    borderLight: Color(0xFFCBD5E1),
  );

  static DColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

extension DColorsX on BuildContext {
  DColors get dc => DColors.of(this);
}
