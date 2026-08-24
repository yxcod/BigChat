import 'package:flutter/material.dart';
import 'package:flutter_base/pages/change_password_page.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    GlobalUtil().userName = 'current-user';
  });

  testWidgets('修改密码使用独立页面并校验两次新密码', (tester) async {
    var requestCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangePasswordPage(
          passwordChanger: (userName, oldPassword, newPassword) async {
            requestCount += 1;
            return 100;
          },
        ),
      ),
    );

    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.enterText(
      find.byKey(const Key('current_password_field')),
      'old-password',
    );
    await tester.enterText(
      find.byKey(const Key('new_password_field')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('confirm_password_field')),
      'different-password',
    );
    await tester.tap(find.byKey(const Key('change_password_complete_button')));
    await tester.pump();

    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    expect(requestCount, 0);
  });

  testWidgets('修改成功后提交新密码并退出当前登录', (tester) async {
    var didLogout = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangePasswordPage(
          passwordChanger: (userName, oldPassword, newPassword) async {
            expect(userName, 'current-user');
            expect(oldPassword, 'old-password');
            expect(newPassword, 'new-password');
            return 100;
          },
          logoutHandler: () async {
            didLogout = true;
          },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('current_password_field')),
      'old-password',
    );
    await tester.enterText(
      find.byKey(const Key('new_password_field')),
      'new-password',
    );
    await tester.enterText(
      find.byKey(const Key('confirm_password_field')),
      'new-password',
    );
    await tester.tap(find.byKey(const Key('change_password_complete_button')));
    await tester.pump();

    expect(find.text('密码修改成功，即将退出登录'), findsOneWidget);
    expect(didLogout, isFalse);

    await tester.pump(const Duration(seconds: 1));
    expect(didLogout, isTrue);
  });
}
