import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _themeKey = 'settings_theme_mode';
  static const _colorKey = 'settings_primary_color';

  ThemeMode _themeMode = ThemeMode.dark;
  Color _primaryColor = const Color(0xFF1DB954);

  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? ThemeMode.dark.index;
    _themeMode = ThemeMode.values[themeIndex.clamp(0, ThemeMode.values.length - 1)];
    final colorValue = prefs.getInt(_colorKey) ?? 0xFF1DB954;
    _primaryColor = Color(colorValue);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.toARGB32());
  }
}
