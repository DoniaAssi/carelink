import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and toggles app light/dark mode (patient home + Material themes).
class ThemeController extends ChangeNotifier {
  static const _key = 'carelink_theme_mode';

  ThemeMode _mode = ThemeMode.light;

  ThemeMode get themeMode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v == 'dark') {
      _mode = ThemeMode.dark;
    } else if (v == 'light') {
      _mode = ThemeMode.light;
    } else {
      _mode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> toggle() async {
    await setTheme(_mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Global instance wired in [main] before [runApp].
final themeController = ThemeController();
