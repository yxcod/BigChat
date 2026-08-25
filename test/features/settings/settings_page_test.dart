import 'package:flutter/material.dart';
import 'package:flutter_base/features/settings/data/app_settings_repository.dart';
import 'package:flutter_base/features/settings/presentation/settings_page.dart';
import 'package:flutter_base/app/theme/app_theme_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings persist toggles and notification sound selection', (
    tester,
  ) async {
    final bools = <String, bool>{};
    final strings = <String, String>{};
    final repository = AppSettingsRepository(
      ownerId: 'alice',
      readBool: (key) => bools[key],
      readString: (key) => strings[key],
      writeBool: (key, value) async {
        bools[key] = value;
      },
      writeString: (key, value) async {
        strings[key] = value;
      },
      importFile: (ownerId, sourcePath) async => '/app/background.jpg',
    );
    var storedDark = false;
    final locationPreferenceChanges = <bool>[];
    final themeController = AppThemeController(
      read: () => storedDark,
      write: (value) async {
        storedDark = value;
        return true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          repository: repository,
          themeController: themeController,
          pickChatBackground: () async => '/gallery/background.jpg',
          locationPreferenceHandler: (enabled) async {
            locationPreferenceChanges.add(enabled);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('隐私模式'), findsOneWidget);
    expect(find.text('位置信息'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('聊天背景设置'), findsOneWidget);
    expect(find.text('主题设置'), findsOneWidget);
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('默认'), findsOneWidget);
    final locationSwitchTile = find.descendant(
      of: find.byKey(const Key('location_enabled_switch')),
      matching: find.byType(SwitchListTile),
    );
    expect(tester.widget<SwitchListTile>(locationSwitchTile).value, isTrue);

    await tester.tap(find.byKey(const Key('location_enabled_switch')));
    await tester.pump();
    expect((await repository.load()).locationEnabled, isFalse);
    expect(locationPreferenceChanges, [false]);

    await tester.tap(find.byKey(const Key('chat_background_settings_entry')));
    await tester.pumpAndSettle();
    expect(find.text('已设置'), findsOneWidget);
    expect((await repository.load()).chatBackgroundPath, '/app/background.jpg');

    await tester.tap(find.byKey(const Key('privacy_mode_switch')));
    await tester.pump();
    expect((await repository.load()).privacyMode, isTrue);

    await tester.tap(find.byKey(const Key('notification_settings_entry')));
    await tester.pumpAndSettle();
    expect(find.text('震动'), findsOneWidget);
    expect(find.text('横幅'), findsOneWidget);
    expect(find.text('消息提示音'), findsOneWidget);
    expect(find.text('消息提示音设置'), findsOneWidget);

    await tester.tap(find.byKey(const Key('vibration_switch')));
    await tester.pump();
    expect((await repository.load()).vibrationEnabled, isFalse);

    await tester.tap(find.byKey(const Key('message_sound_settings_entry')));
    await tester.pumpAndSettle();
    expect(find.text('系统默认'), findsOneWidget);
    expect(find.text('三全音'), findsOneWidget);
    expect(find.text('玻璃'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notification_sound_glass')));
    await tester.pumpAndSettle();

    expect(find.text('玻璃'), findsOneWidget);
    expect((await repository.load()).messageSoundId, 'glass');

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme_settings_entry')));
    await tester.pumpAndSettle();
    expect(find.text('浅色主题'), findsOneWidget);
    expect(find.text('深色主题'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dark_theme_option')));
    await tester.pumpAndSettle();
    expect(themeController.themeMode, ThemeMode.dark);
    expect(storedDark, isTrue);
  });

  testWidgets('退出登录需要确认并清理到登录路由', (tester) async {
    var loggedOut = false;
    final repository = AppSettingsRepository(
      ownerId: 'alice',
      readBool: (_) => null,
      readString: (_) => null,
      writeBool: (_, _) async {},
      writeString: (_, _) async {},
    );

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => SettingsPage(
            repository: repository,
            logoutHandler: () async {
              loggedOut = true;
            },
          ),
          '/login': (_) => const Scaffold(body: Text('登录页面')),
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('logout_button')));
    await tester.pumpAndSettle();
    expect(find.text('退出后将返回登录页面，本地账号登录状态会被清除。'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_logout_button')));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
    expect(find.text('登录页面'), findsOneWidget);
  });
}
