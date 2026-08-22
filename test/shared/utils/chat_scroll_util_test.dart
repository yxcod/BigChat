import 'package:flutter/material.dart';
import 'package:flutter_base/shared/utils/chat_scroll_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'reversed chat list shows the latest message on its first frame',
    (tester) async {
      final controller = ScrollController();
      final messages = List.generate(120, (index) => '消息 $index');

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            height: 300,
            child: ListView.builder(
              controller: controller,
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (_, index) => SizedBox(
                height: 72,
                child: Text(messages[messages.length - 1 - index]),
              ),
            ),
          ),
        ),
      );

      expect(controller.offset, controller.position.minScrollExtent);
      expect(find.text('消息 119'), findsOneWidget);
      expect(find.text('消息 0'), findsNothing);
      controller.dispose();
    },
  );

  testWidgets('keeps a lazily built chat list aligned to its bottom', (
    tester,
  ) async {
    final controller = ScrollController();
    var active = true;

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 300,
          child: ListView.builder(
            controller: controller,
            itemCount: 120,
            itemBuilder: (_, index) => SizedBox(
              height: index.isEven ? 48 : 132,
              child: Text('消息 $index'),
            ),
          ),
        ),
      ),
    );

    ChatScrollUtil.scheduleJumpToBottom(
      controller: controller,
      isActive: () => active,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(controller.position.extentAfter, lessThan(1));
    active = false;
    await tester.pump(const Duration(milliseconds: 40));
    controller.dispose();
  });
}
