import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/swipe_action_cell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('left swipe reveals delete and requires an explicit tap', (
    tester,
  ) async {
    var deleteCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeActionCell(
            onDelete: () => deleteCount++,
            child: const SizedBox(
              key: ValueKey('conversation'),
              height: 72,
              child: Text('会话'),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('swipe_delete_action')), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('conversation')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    expect(deleteCount, 0);
    expect(find.byKey(const ValueKey('swipe_delete_action')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('swipe_delete_action')));
    expect(deleteCount, 1);
  });
}
