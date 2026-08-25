import 'package:flutter_base/app/theme/app_colors.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/app/theme/app_theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme exposes a consistent brand color and component defaults', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.primaryColor, AppColors.primary);
    expect(theme.appBarTheme.backgroundColor, AppColors.surface);
    expect(theme.scaffoldBackgroundColor, AppColors.pageBackground);
    expect(theme.useMaterial3, isFalse);
  });

  test('dark theme uses dark semantic surfaces and remains green branded', () {
    final theme = AppTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, isNot(AppColors.surface));
    expect(theme.colorScheme.onSurface.computeLuminance(), greaterThan(0.5));
  });

  test(
    'theme controller restores and persists explicit theme selection',
    () async {
      var storedDark = false;
      final controller = AppThemeController(
        read: () => storedDark,
        write: (isDark) async {
          storedDark = isDark;
          return true;
        },
      );

      await controller.load();
      expect(controller.themeMode, ThemeMode.light);

      await controller.setThemeMode(ThemeMode.dark);
      expect(controller.themeMode, ThemeMode.dark);
      expect(storedDark, isTrue);
    },
  );
}
