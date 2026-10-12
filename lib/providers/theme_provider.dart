import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _prefKey = 'app_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool(_prefKey) ?? true;
      state = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {}
  }

  Future<void> toggle() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = newMode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, newMode == ThemeMode.dark);
    } catch (_) {}
  }

  Future<void> toggleTheme() => toggle();
}
