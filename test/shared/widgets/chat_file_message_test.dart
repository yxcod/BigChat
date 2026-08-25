import 'package:flutter/material.dart';
import 'package:flutter_base/core/media/chat_file.dart';
import 'package:flutter_base/shared/widgets/chat_file_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('file bubble shows live upload percentage', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChatFileMessage(
            payload: ChatFilePayload(
              storedName: 'alice_bob_1.zip',
              originalName: '资料.zip',
              sizeBytes: 1024 * 1024,
              ownerId: 'alice',
            ),
            uploadProgress: 0.42,
          ),
        ),
      ),
    );

    expect(find.text('资料.zip'), findsOneWidget);
    expect(find.text('正在发送 42%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
