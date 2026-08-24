import 'package:flutter/material.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_base/shared/widgets/quoted_message_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quoted message style survives unrelated screen taps', (
    tester,
  ) async {
    const quote = MessageQuote(
      messageId: 1,
      senderId: 'alice',
      senderLabel: '小艾',
      preview: '[语音] 14秒',
      messageType: MessageType.audio,
    );
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => taps++),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuotedTextMessageBubble(
                    quote: quote,
                    text: '收到',
                    bubbleColor: Colors.blue,
                    textColor: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  Text('taps:$taps'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(find.byKey(const ValueKey('quoted_text_message_bubble')), findsOne);
    expect(find.text('小艾'), findsOne);
    expect(find.text('[语音] 14秒'), findsOne);
    expect(find.text('收到'), findsOne);
    expect(find.text('taps:1'), findsOne);
  });
}
