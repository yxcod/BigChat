import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/pages/LoginPages/loginWidget.dart';
import 'package:flutter_base/shared/widgets/user_agreement_dialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('登录页使用应用图标和紧凑登录卡片', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const BigchatLoginPage()),
    );

    expect(find.byKey(const Key('login_app_icon')), findsOneWidget);
    expect(find.byKey(const Key('login_form_card')), findsOneWidget);
    expect(find.text('全信'), findsOneWidget);
    expect(find.text('连接彼此，分享此刻'), findsNothing);
    expect(find.text('忘记密码'), findsOneWidget);
    expect(find.text('注册账号'), findsOneWidget);
    expect(find.textContaining('用户协议'), findsOneWidget);
    expect(find.textContaining('隐私政策'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未同意用户协议时不发送登录请求', (tester) async {
    var requestCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: BigchatLoginPage(
          loginHandler: (userName, password) async {
            requestCount += 1;
            return {'code': 101};
          },
        ),
      ),
    );

    await tester.enterText(
      _fieldInside(const Key('login_account_field')),
      '13800138000',
    );
    await tester.enterText(
      _fieldInside(const Key('login_password_field')),
      'password',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pump();

    expect(find.text('请先阅读并同意用户协议'), findsOneWidget);
    expect(requestCount, 0);
  });

  testWidgets('点击用户协议显示指定协议内容', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const BigchatLoginPage()),
    );

    await tester.tap(find.byKey(const Key('login_user_agreement_link')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('user_agreement_dialog')), findsOneWidget);
    expect(find.text(userAgreementContent), findsOneWidget);
    expect(find.text('隐私政策'), findsNothing);
  });

  testWidgets('点击左侧忘记密码按钮直接进入找回密码页面', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const BigchatLoginPage()),
    );

    await tester.tap(find.byKey(const Key('login_forgot_password_button')));
    await tester.pumpAndSettle();

    expect(find.text('找回密码'), findsOneWidget);
    expect(find.byKey(const Key('forgot_password_form_card')), findsOneWidget);
    expect(find.text('确认修改'), findsOneWidget);
  });
}

Finder _fieldInside(Key key) {
  return find.descendant(of: find.byKey(key), matching: find.byType(TextField));
}
