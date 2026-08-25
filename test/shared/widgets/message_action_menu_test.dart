import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/message_action_menu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('message action popup returns the selected grid action', (
    tester,
  ) async {
    MessageActionType? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showMessageActionMenu(
                    context: context,
                    anchor: const Offset(180, 385),
                    targetRect: const Rect.fromLTWH(120, 360, 120, 50),
                    actions: const [
                      MessageActionItem(
                        type: MessageActionType.delete,
                        label: '删除',
                        icon: Icons.delete_outline,
                      ),
                      MessageActionItem(
                        type: MessageActionType.quote,
                        label: '引用',
                        icon: Icons.format_quote,
                      ),
                    ],
                  );
                },
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);
    expect(find.text('引用'), findsOneWidget);
    final menuFinder = find.byKey(const ValueKey('message_action_menu'));
    expect(tester.getSize(menuFinder).width, lessThan(200));
    expect(tester.getBottomLeft(menuFinder).dy, lessThanOrEqualTo(360));

    await tester.tap(find.byKey(const ValueKey('message_action_quote')));
    await tester.pumpAndSettle();
    expect(selected, MessageActionType.quote);
  });
}
