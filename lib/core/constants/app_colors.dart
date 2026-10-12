import 'package:flutter/material.dart';

class AppColors {
  // Financial Orange & Gold Accents (Bitcoin / Bloomberg terminal aesthetic)
  static const Color primary = Color(0xFFFF7A00); // Radiant Bitcoin Orange
  static const Color primaryLight = Color(0xFFFFA043);
  static const Color primaryDark = Color(0xFFCC5E00);
  static const Color primaryGlow = Color(0x33FF7A00);
  static const Color gold = Color(0xFFF59E0B);

  // Financial Market Indicators
  static const Color profit = Color(0xFF00C087); // Emerald Bullish Green
  static const Color profitBg = Color(0x1F00C087);
  static const Color loss = Color(0xFFFF3B30); // Crimson Bearish Red
  static const Color lossBg = Color(0x1FFF3B30);

  // 🌑 Dark Mode Palette (Pure Jet Black / Obsidian Financial Terminal)
  static const Color darkBackground = Color(0xFF08080A);
  static const Color darkSurface = Color(0xFF131317);
  static const Color darkSurfaceLight = Color(0xFF1C1D24);
  static const Color darkBorder = Color(0xFF262732);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFF9E9EA8);
  static const Color darkTextMuted = Color(0xFF626370);

  // ☀️ Light Mode Palette (Crisp High-End Wall Street White / Slate)
  static const Color lightBackground = Color(0xFFF4F5F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFE9EBEF);
  static const Color lightBorder = Color(0xFFDCE0E6);
  static const Color lightTextPrimary = Color(0xFF111317);
  static const Color lightTextSecondary = Color(0xFF555B68);
  static const Color lightTextMuted = Color(0xFF8890A0);

  // Dynamic getters based on brightness
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBackground : lightBackground;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color surfaceLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSurfaceLight : lightSurfaceLight;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : lightBorder;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : lightTextSecondary;

  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextMuted : lightTextMuted;

  // Pie Chart Colors
  static const List<Color> chartColors = [
    Color(0xFFFF7A00), // Bitcoin Orange
    Color(0xFF3B82F6), // Blue
    Color(0xFF00C087), // Green
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber Gold
  ];
}
