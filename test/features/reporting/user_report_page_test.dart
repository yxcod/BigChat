import 'package:flutter/material.dart';
import 'package:flutter_base/features/reporting/presentation/user_report_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('report form is UI-only and never claims a successful upload', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserReportPage(userName: '10001', displayName: '小李'),
      ),
    );

    expect(find.text('举报用户'), findsOneWidget);
    expect(find.text('账号：10001'), findsOneWidget);
    await tester.tap(find.byKey(const Key('report_reason_2')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('report_submit_button')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('report_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('举报功能暂未开放'), findsOneWidget);
    expect(find.textContaining('不会上传或保存'), findsOneWidget);
    expect(find.textContaining('举报成功'), findsNothing);
  });
}
