import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/pages/LoginPages/registerPage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('注册页使用紧凑卡片并展示完整注册入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const RegisterPage()),
    );

    expect(find.text('创建账号'), findsOneWidget);
    expect(find.text('填写信息，开始使用全信'), findsOneWidget);
    expect(find.byKey(const Key('register_form_card')), findsOneWidget);
    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
    expect(find.text('确认密码'), findsOneWidget);
    expect(find.text('立即登录'), findsOneWidget);
    expect(find.textContaining('用户协议'), findsOneWidget);
    expect(find.textContaining('隐私政策'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('注册表单校验后只提交账号和密码', (tester) async {
    String? submittedAccount;
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: RegisterPage(
          registerHandler: (account, password) async {
            submittedAccount = account;
            submittedPassword = password;
            return {'code': 101};
          },
        ),
      ),
    );

    await tester.enterText(
      _fieldInside(const Key('register_phone_field')),
      '13800138000',
    );
    await tester.enterText(
      _fieldInside(const Key('register_password_field')),
      'secret123',
    );
    await tester.enterText(
      _fieldInside(const Key('register_confirm_password_field')),
      'secret123',
    );
    await tester.tap(find.byKey(const Key('register_submit_button')));
    await tester.pumpAndSettle();

    expect(submittedAccount, '13800138000');
    expect(submittedPassword, 'secret123');
    expect(find.text('该账号已注册'), findsOneWidget);
  });

  testWidgets('注册页在深色主题下使用深色表面', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const RegisterPage()),
    );

    final card = tester.widget<Container>(
      find.byKey(const Key('register_form_card')),
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, AppTheme.dark.colorScheme.surface);
    expect(decoration.color, isNot(Colors.white));
  });
}

Finder _fieldInside(Key key) {
  return find.descendant(
    of: find.byKey(key),
    matching: find.byType(TextFormField),
  );
}
