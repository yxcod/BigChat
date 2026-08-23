import 'package:flutter/material.dart';
import 'package:flutter_base/features/settings/data/app_settings_repository.dart';
import 'package:flutter_base/features/settings/presentation/settings_page.dart';
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
    );

    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('隐私模式'), findsOneWidget);
    expect(find.text('位置信息'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);

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
  });
}
