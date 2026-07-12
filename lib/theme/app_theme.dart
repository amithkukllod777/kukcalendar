import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kuklabs universal design tokens (see KUKLABS_IDENTITY.md §6, §26).
///
/// The whole ecosystem shares ONE neutral + semantic palette and ONE type
/// system (Inter). Only the product accent may change per app — Kuk Calendar
/// uses the family blue accent-600 (#2868F0), same as KukKeep.
class AppColors {
  AppColors._();

  // Product accent (accent-600) + a pressed/dark shade (accent-700).
  static const Color primary = Color(0xFF2868F0);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color accentSurface = Color(0xFFEFF6FF); // accent-50

  // Neutral foundation.
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFF2F4F7);
  static const Color fill = Color(0xFFF2F4F7);
  static const Color border = Color(0xFFD0D5DD);
  static const Color borderSubtle = Color(0xFFEAECF0);

  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF475467);
  static const Color textMuted = Color(0xFF667085);
  static const Color placeholder = Color(0xFF98A2B3);

  // Semantic colours (shared across every Kuklabs app — never re-tinted).
  static const Color success = Color(0xFF039855);
  static const Color warning = Color(0xFFDC6803);
  static const Color danger = Color(0xFFD92D20);
  static const Color info = Color(0xFF1570EF);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    surface: AppColors.surface,
    error: AppColors.danger,
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    // Inter is mandatory across every Kuklabs app (KUKLABS_IDENTITY.md §5).
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    primaryTextTheme: GoogleFonts.interTextTheme(base.primaryTextTheme),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    dividerColor: AppColors.borderSubtle,
  );
}
