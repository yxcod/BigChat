import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_context.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const String _appName = '全信';
  static const String _version = '1.0.0';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(title: const Text('关于全信')),
      body: ListView(
        children: [
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _appName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Version $_version',
                  style: TextStyle(
                    fontSize: 15,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Material(
            color: context.appSurface,
            child: ListTile(
              key: const Key('version_update_tile'),
              title: const Text('版本更新'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '当前已是最新版本',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: context.appTextSecondary),
                ],
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('当前已是最新版本'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
