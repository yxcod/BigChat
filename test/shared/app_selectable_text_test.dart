import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_base/shared/widgets/app_selectable_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selection is scoped to one text and uses Chinese actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Column(
            children: [
              AppSelectableText('第一条动态的完整文字'),
              AppSelectableText('第二条动态不应一起选中'),
            ],
          ),
        ),
      ),
    );

    await tester.longPress(find.text('第一条动态的完整文字'));
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
    expect(find.text('全选'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
  });
}
