import 'package:flutter/material.dart';

extension AppThemeContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);

  bool get isDarkMode => appTheme.brightness == Brightness.dark;

  Color get appSurface => appTheme.colorScheme.surface;

  Color get appPageBackground => appTheme.scaffoldBackgroundColor;

  Color get appTextPrimary => appTheme.colorScheme.onSurface;

  Color get appTextSecondary => appTheme.colorScheme.onSurfaceVariant;

  Color get appDivider => appTheme.dividerColor;

  Color get appSearchBackground =>
      isDarkMode ? const Color(0xFF24282D) : const Color(0xFFF3F3F5);

  Color get appElevatedSurface =>
      isDarkMode ? const Color(0xFF202429) : appTheme.colorScheme.surface;
}
