import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/hold_to_record_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('chat input shows the voice recording hint by default', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoldToRecordField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (_) {},
            onSubmitted: (_) {},
            onRecorded: (_) async {},
            onError: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('长按发送语音'), findsOneWidget);
  });
}
