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

  testWidgets('tapping outside the search field releases focus', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppSearchField(
                controller: controller,
                query: '',
                hintText: '搜索',
                onChanged: (_) {},
              ),
              const Expanded(
                child: ColoredBox(
                  key: Key('search_test_blank_area'),
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('search_test_blank_area'))),
    );
    await tester.pump();
    expect(editableText.focusNode.hasFocus, isFalse);
  });
}
