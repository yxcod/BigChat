import 'package:flutter/material.dart';

import '../../utils/storageUtil.dart';

typedef ThemeModeReader = bool Function();
typedef ThemeModeWriter = Future<bool> Function(bool isDark);

class AppThemeController extends ChangeNotifier {
  AppThemeController({ThemeModeReader? read, ThemeModeWriter? write})
    : _read = read ?? StorageUtil.isDarkMode,
      _write = write ?? StorageUtil.setThemeMode;

  static final AppThemeController instance = AppThemeController();

  final ThemeModeReader _read;
  final ThemeModeWriter _write;
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  Future<void> load() async {
    final restored = _read() ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == restored) return;
    _themeMode = restored;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    final normalized = value == ThemeMode.dark
        ? ThemeMode.dark
        : ThemeMode.light;
    if (_themeMode == normalized) return;
    _themeMode = normalized;
    notifyListeners();
    await _write(normalized == ThemeMode.dark);
  }
}
