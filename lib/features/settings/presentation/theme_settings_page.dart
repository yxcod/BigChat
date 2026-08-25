import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../app/theme/app_theme_controller.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key, required this.controller});

  final AppThemeController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        backgroundColor: context.appPageBackground,
        appBar: AppBar(title: const Text('主题设置')),
        body: ListView(
          padding: const EdgeInsets.only(top: 12),
          children: [
            Material(
              color: context.appSurface,
              child: Column(
                children: [
                  _ThemeOptionTile(
                    key: const Key('light_theme_option'),
                    title: '浅色主题',
                    selected: controller.themeMode == ThemeMode.light,
                    onTap: () => controller.setThemeMode(ThemeMode.light),
                  ),
                  Divider(height: 1, indent: 16, color: context.appDivider),
                  _ThemeOptionTile(
                    key: const Key('dark_theme_option'),
                    title: '深色主题',
                    selected: controller.themeMode == ThemeMode.dark,
                    onTap: () => controller.setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: AppColors.primary)
          : null,
      onTap: onTap,
    );
  }
}
