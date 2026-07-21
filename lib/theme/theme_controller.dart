import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode (system / light / dark), persisted across launches.
/// The MaterialApp listens to this and rebuilds; the app shell also sets
/// AppColors.brightness from the resolved mode so the token getters flip.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.system);
  static final ThemeController instance = ThemeController._();

  static const _key = 'kc_theme_mode';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      value = switch (p.getString(_key)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {/* default = system */}
  }

  Future<void> set(ThemeMode mode) async {
    value = mode;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, mode.name);
    } catch (_) {/* non-fatal */}
  }

  String get label => switch (value) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System default',
      };
}
