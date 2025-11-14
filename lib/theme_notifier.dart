import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDark = false;
  bool get isDark => _isDark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeNotifier() {
    _loadTheme(); // load saved preference
  }

  void toggleTheme(bool darkMode) {
    _isDark = darkMode;
    _saveTheme(darkMode);
    notifyListeners();
  }

  Future<void> _saveTheme(bool darkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', darkMode);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final darkMode = prefs.getBool('isDarkMode') ?? false;
    _isDark = darkMode;
    notifyListeners(); // ask listeners (MaterialApp) to rebuild with loaded theme
  }
}
