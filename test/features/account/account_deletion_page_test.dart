import 'package:flutter/material.dart';
import 'package:flutter_base/features/account/data/account_deletion_repository.dart';
import 'package:flutter_base/features/account/presentation/account_deletion_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> fillDeletionForm(WidgetTester tester) async {
    final acknowledgement = find.byKey(
      const Key('account_deletion_acknowledgement'),
    );
    await tester.scrollUntilVisible(
      acknowledgement,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(acknowledgement);

    final password = find.byKey(const Key('account_deletion_password_field'));
    await tester.scrollUntilVisible(
      password,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(password, 'current-password');

    final phrase = find.byKey(const Key('account_deletion_phrase_field'));
    await tester.scrollUntilVisible(
      phrase,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(phrase, '注销账户');
    await tester.pump();
  }

  testWidgets('注销按钮仅在完成全部风险确认后启用', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionPage(
          deletionExecutor: (_) async =>
              const AccountDeletionResult(code: 100, message: '账户已注销'),
        ),
      ),
    );

    final button = find.byKey(const Key('delete_account_button'));
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await fillDeletionForm(tester);
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });

  testWidgets('永久注销需要二次确认并清理本地登录状态', (tester) async {
    String? submittedPassword;
    var cleanedUp = false;

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/': (_) => AccountDeletionPage(
            deletionExecutor: (password) async {
              submittedPassword = password;
              return const AccountDeletionResult(code: 100, message: '账户已注销');
            },
            localCleanup: () async {
              cleanedUp = true;
            },
          ),
          '/login': (_) => const Scaffold(body: Text('登录页面')),
        },
      ),
    );

    await fillDeletionForm(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete_account_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pumpAndSettle();

    expect(find.text('最后确认'), findsOneWidget);
    expect(submittedPassword, isNull);

    await tester.tap(find.byKey(const Key('final_delete_account_button')));
    await tester.pumpAndSettle();

    expect(submittedPassword, 'current-password');
    expect(cleanedUp, isTrue);
    expect(find.text('登录页面'), findsOneWidget);
  });

  testWidgets('后端拒绝注销时显示具体原因并保留当前页面', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountDeletionPage(
          deletionExecutor: (_) async =>
              const AccountDeletionResult(code: 103, message: '请先解散或转让由你创建的群聊'),
          localCleanup: () async {},
        ),
      ),
    );

    await fillDeletionForm(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete_account_button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('delete_account_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('final_delete_account_button')));
    await tester.pumpAndSettle();

    expect(find.text('请先解散或转让由你创建的群聊'), findsOneWidget);
    expect(find.text('账户注销'), findsOneWidget);
  });
}
