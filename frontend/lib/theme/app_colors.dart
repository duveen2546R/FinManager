import 'package:flutter/material.dart';

// Neobank palette: warm light-gray canvas, flat white cards, black pill
// buttons, lime accent. Light-first; dark mode is a tasteful inversion.
class AppColors {
  final bool isDark;
  final Color primary; // pill buttons / active elements
  final Color onPrimary; // content on primary
  final Color accent; // lime
  final Color onAccent; // content on lime
  final Color background;
  final Color card; // flat card surface
  final Color elevated; // input fills / soft chips on cards
  final Color text;
  final Color secondaryText;
  final Color border;
  final Color income;
  final Color expense;

  const AppColors({
    required this.isDark,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.card,
    required this.elevated,
    required this.text,
    required this.secondaryText,
    required this.border,
    required this.income,
    required this.expense,
  });

  static const AppColors light = AppColors(
    isDark: false,
    primary: Color(0xFF1A1A1A),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFC8E84E),
    onAccent: Color(0xFF171717),
    background: Color(0xFFF4F4F2),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFF1F1EF),
    text: Color(0xFF171717),
    secondaryText: Color(0xFF8A8A86),
    border: Color(0xFFE8E8E6),
    income: Color(0xFF2F9E44),
    expense: Color(0xFFE5484D),
  );

  static const AppColors dark = AppColors(
    isDark: true,
    primary: Color(0xFFF4F4F2),
    onPrimary: Color(0xFF171717),
    accent: Color(0xFFC8E84E),
    onAccent: Color(0xFF171717),
    background: Color(0xFF141414),
    card: Color(0xFF1E1E1E),
    elevated: Color(0xFF2A2A2C),
    text: Color(0xFFF4F4F2),
    secondaryText: Color(0xFF9C9C98),
    border: Color(0xFF2E2E30),
    income: Color(0xFF57C46B),
    expense: Color(0xFFF26D6D),
  );
}
