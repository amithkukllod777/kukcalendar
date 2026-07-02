import 'package:flutter/material.dart';

/// Brand palette for Kuk Calendar (matches the KukLabs violet).
class AppColors {
  AppColors._();
  static const Color primary = Color(0xFF6D5DF6);
  static const Color primaryDark = Color(0xFF5B4BD6);
  static const Color bg = Color(0xFFF7F7FE);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE6E4F6);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color fill = Color(0xFFF3F4F6);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    dividerColor: AppColors.border,
  );
}
