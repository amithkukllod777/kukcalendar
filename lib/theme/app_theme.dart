import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kuklabs universal design tokens (see KUKLABS_IDENTITY.md §6, §26).
///
/// The whole ecosystem shares ONE neutral + semantic palette and ONE type
/// system (Inter). Only the product accent may change per app — Kuk Calendar
/// uses the family blue accent-600 (#2868F0).
///
/// Dark mode: every neutral resolves through [brightness], so the 100+ existing
/// `AppColors.x` call sites flip automatically when the app theme changes. The
/// canonical LIGHT values are unchanged (standard-compliant); dark is a matched
/// neutral ramp. Semantic + accent hues are shared, nudged only for contrast.
class AppColors {
  AppColors._();

  /// Set by the app shell each build from the resolved ThemeMode, so the getters
  /// below return the right value. Defaults to light.
  static Brightness brightness = Brightness.light;
  static bool get _dark => brightness == Brightness.dark;
  static Color _pick(Color light, Color dark) => _dark ? dark : light;

  // Product accent (accent-600 light / accent-400 dark for contrast on dark bg).
  static Color get primary => _pick(const Color(0xFF2868F0), const Color(0xFF5B8CFF));
  static Color get primaryDark => _pick(const Color(0xFF1D4ED8), const Color(0xFF3B6FE0));
  static Color get accentSurface =>
      _pick(const Color(0xFFEFF6FF), const Color(0xFF16233D));

  // Neutral foundation.
  static Color get bg => _pick(const Color(0xFFF8FAFC), const Color(0xFF0B1220));
  static Color get surface => _pick(const Color(0xFFFFFFFF), const Color(0xFF161E2E));
  static Color get surfaceSecondary =>
      _pick(const Color(0xFFF2F4F7), const Color(0xFF1E2739));
  static Color get fill => _pick(const Color(0xFFF2F4F7), const Color(0xFF1E2739));
  static Color get border => _pick(const Color(0xFFD0D5DD), const Color(0xFF344054));
  static Color get borderSubtle =>
      _pick(const Color(0xFFEAECF0), const Color(0xFF283042));

  static Color get textPrimary =>
      _pick(const Color(0xFF101828), const Color(0xFFF2F4F7));
  static Color get textSecondary =>
      _pick(const Color(0xFF475467), const Color(0xFF98A2B3));
  static Color get textMuted =>
      _pick(const Color(0xFF667085), const Color(0xFF7A8699));
  static Color get placeholder =>
      _pick(const Color(0xFF98A2B3), const Color(0xFF5C6B7F));

  // Semantic colours (shared; slightly lifted in dark for contrast).
  static Color get success => _pick(const Color(0xFF039855), const Color(0xFF32D583));
  static Color get warning => _pick(const Color(0xFFDC6803), const Color(0xFFFDB022));
  static Color get danger => _pick(const Color(0xFFD92D20), const Color(0xFFF97066));
  static Color get info => _pick(const Color(0xFF1570EF), const Color(0xFF53B1FD));
}

ThemeData buildAppTheme() => _themeFor(Brightness.light);
ThemeData buildDarkTheme() => _themeFor(Brightness.dark);

ThemeData _themeFor(Brightness b) {
  final dark = b == Brightness.dark;
  // Resolve tokens for this brightness (independent of the live global flag).
  Color pick(Color l, Color d) => dark ? d : l;
  final primary = pick(const Color(0xFF2868F0), const Color(0xFF5B8CFF));
  final bg = pick(const Color(0xFFF8FAFC), const Color(0xFF0B1220));
  final surface = pick(const Color(0xFFFFFFFF), const Color(0xFF161E2E));
  final textPrimary = pick(const Color(0xFF101828), const Color(0xFFF2F4F7));
  final borderSubtle = pick(const Color(0xFFEAECF0), const Color(0xFF283042));

  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2868F0),
    brightness: b,
  ).copyWith(
    primary: primary,
    surface: surface,
    error: pick(const Color(0xFFD92D20), const Color(0xFFF97066)),
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: bg,
  );
  return base.copyWith(
    // Inter is mandatory across every Kuklabs app (KUKLABS_IDENTITY.md §5).
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    primaryTextTheme: GoogleFonts.interTextTheme(base.primaryTextTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: textPrimary),
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: borderSubtle,
  );
}
