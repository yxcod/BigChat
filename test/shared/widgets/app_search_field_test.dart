import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/app_search_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppSearchField forwards input and clears the query', (
    tester,
  ) async {
    final controller = TextEditingController(text: '你好');
    var value = '你好';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppSearchField(
            controller: controller,
            query: value,
            hintText: '搜索',
            onChanged: (nextValue) => value = nextValue,
          ),
        ),
      ),
    );

    expect(find.byTooltip('清除'), findsOneWidget);
    expect(tester.getSize(find.byType(TextField)).height, 44);
    await tester.tap(find.byTooltip('清除'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(value, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
