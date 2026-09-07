import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ThemeModeController customerThemeMode = ThemeModeController();

class ThemeModeController extends ValueNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.dark) {
    _loadTheme();
  }

  static const _key = 'customer_theme_mode';

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(_key);
      if (savedIndex != null && savedIndex >= 0 && savedIndex < ThemeMode.values.length) {
        value = ThemeMode.values[savedIndex];
      }
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, mode.index);
    } catch (_) {}
  }

  void cycle() {
    final nextMode = switch (value) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    setTheme(nextMode);
  }
}
