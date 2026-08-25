import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/pages/LoginPages/forgot_password_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('安全码是当前日期 yyyyMMdd 的倒序', () {
    expect(passwordSecurityCodeForDate(DateTime(2026, 8, 25)), '52806202');
    expect(passwordSecurityCodeForDate(DateTime(2027, 1, 3)), '30107202');
  });

  testWidgets('安全码错误时在输入框下提示且不请求重置密码', (tester) async {
    var requestCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ForgotPasswordPage(
          now: () => DateTime(2026, 8, 25),
          passwordResetter: (userName, newPassword) async {
            requestCount += 1;
            return 100;
          },
        ),
      ),
    );

    await tester.enterText(
      _fieldInside(const Key('forgot_password_account_field')),
      '13800138000',
    );
    await tester.enterText(
      _fieldInside(const Key('forgot_password_security_code_field')),
      '12345678',
    );
    await tester.enterText(
      _fieldInside(const Key('forgot_password_new_password_field')),
      'new-password',
    );
    await tester.tap(find.byKey(const Key('forgot_password_submit_button')));
    await tester.pump();

    expect(find.text('安全码错误 请联系管理员'), findsOneWidget);
    expect(requestCount, 0);
  });

  testWidgets('安全码正确时提交账号和新密码', (tester) async {
    String? submittedAccount;
    String? submittedPassword;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ForgotPasswordPage(
          now: () => DateTime(2026, 8, 25),
          passwordResetter: (userName, newPassword) async {
            submittedAccount = userName;
            submittedPassword = newPassword;
            return 102;
          },
        ),
      ),
    );

    await tester.enterText(
      _fieldInside(const Key('forgot_password_account_field')),
      '13800138000',
    );
    await tester.enterText(
      _fieldInside(const Key('forgot_password_security_code_field')),
      '52806202',
    );
    await tester.enterText(
      _fieldInside(const Key('forgot_password_new_password_field')),
      'new-password',
    );
    await tester.tap(find.byKey(const Key('forgot_password_submit_button')));
    await tester.pumpAndSettle();

    expect(submittedAccount, '13800138000');
    expect(submittedPassword, 'new-password');
    expect(find.text('账号不存在，请检查后重试'), findsOneWidget);
  });

  testWidgets('忘记密码页在深色主题下使用深色表面', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: ForgotPasswordPage(now: () => DateTime(2026, 8, 25)),
      ),
    );

    final card = tester.widget<Container>(
      find.byKey(const Key('forgot_password_form_card')),
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
