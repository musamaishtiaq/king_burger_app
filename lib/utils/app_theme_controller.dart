import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and broadcasts app light/dark mode from Printer Settings.
class AppThemeController extends ChangeNotifier {
  AppThemeController._();

  static final AppThemeController instance = AppThemeController._();

  static const String prefKey = 'appThemeMode';
  static const String modeLight = 'light';
  static const String modeDark = 'dark';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  String get storedMode =>
      _themeMode == ThemeMode.dark ? modeDark : modeLight;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _applyModeString(prefs.getString(prefKey) ?? modeLight, notify: false);
    _syncSystemChrome();
    notifyListeners();
  }

  Future<void> setModeString(String mode) async {
    final normalized = mode == modeDark ? modeDark : modeLight;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, normalized);
    _applyModeString(normalized);
  }

  void _applyModeString(String mode, {bool notify = true}) {
    _themeMode = mode == modeDark ? ThemeMode.dark : ThemeMode.light;
    _syncSystemChrome();
    if (notify) notifyListeners();
  }

  void _syncSystemChrome() {
    final isDark = _themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );
  }
}
