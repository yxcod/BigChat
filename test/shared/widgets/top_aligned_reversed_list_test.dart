import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/top_aligned_reversed_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sparse reversed chat messages start at the top', (tester) async {
    final controller = ScrollController();
    final messages = ['较早消息', '最新消息'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: TopAlignedReversedList(
              controller: controller,
              itemCount: messages.length,
              itemBuilder: (context, index) => SizedBox(
                height: 64,
                child: Text(messages[messages.length - 1 - index]),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.text('较早消息')).dy, lessThan(80));
    expect(
      tester.getTopLeft(find.text('最新消息')).dy,
      greaterThan(tester.getTopLeft(find.text('较早消息')).dy),
    );
    controller.dispose();
  });

  testWidgets('large reversed history keeps newest message on first frame', (
    tester,
  ) async {
    final controller = ScrollController();
    final messages = List.generate(40, (index) => '消息 $index');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: TopAlignedReversedList(
              controller: controller,
              itemCount: messages.length,
              itemBuilder: (context, index) => SizedBox(
                height: 64,
                child: Text(messages[messages.length - 1 - index]),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('消息 39'), findsOneWidget);
    expect(find.text('消息 0'), findsNothing);
    controller.dispose();
  });
}
