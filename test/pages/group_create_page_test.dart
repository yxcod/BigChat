import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/pages/groupPages/groupCreatePage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('group creation chrome uses one color and a thin divider', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const GroupCreatePage()),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(scaffold.backgroundColor, Colors.white);
    expect(appBar.backgroundColor, Colors.white);
    expect(appBar.surfaceTintColor, Colors.white);
    expect(appBar.elevation, 0);
    expect(appBar.scrolledUnderElevation, 0);
    expect(appBar.systemOverlayStyle?.statusBarColor, Colors.white);
    expect(appBar.systemOverlayStyle?.statusBarIconBrightness, Brightness.dark);
    expect(appBar.bottom?.preferredSize.height, 0.5);

    final divider = tester.widget<Divider>(find.byType(Divider).first);
    expect(divider.height, 0.5);
    expect(divider.thickness, 0.5);
  });

  testWidgets('创建群聊页面包含头像和紧凑表单且不显示说明文字', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const GroupCreatePage()),
    );

    expect(find.text('上传群头像'), findsOneWidget);
    expect(find.byKey(const ValueKey('group_avatar_picker')), findsOneWidget);
    expect(find.text('群号'), findsOneWidget);
    expect(find.text('请输入群号'), findsOneWidget);
    expect(find.text('群名称'), findsOneWidget);
    expect(find.text('请输入群名称'), findsOneWidget);
    expect(find.text('群名称可在创建后修改'), findsNothing);

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('create_group_button')),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('群号只允许输入六位数字', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const GroupCreatePage()),
    );

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('group_id_field')),
        matching: find.byType(TextField),
      ),
      '12a34567',
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('group_id_field')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller?.text, '123456');
    expect(find.text('请输入6位群号'), findsNothing);
  });
}
