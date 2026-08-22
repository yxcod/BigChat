import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/features/chat/domain/chat_realtime_event.dart';

void main() {
  test('parses private incoming message', () {
    final event = ChatRealtimeEvent.parse({
      'type': 'message',
      'msgId': '12',
      'sendUserId': 'alice',
      'msgContent': 'hello',
      'msgType': 1,
      'sessionId': 'bob_alice',
      'sendTime': 1000,
    });

    expect(event.type, ChatRealtimeEventType.privateMessage);
    expect(event.messageId, 12);
    expect(event.senderId, 'alice');
    expect(event.content, 'hello');
  });

  test('distinguishes group delivery acknowledgement from read receipt', () {
    final delivery = ChatRealtimeEvent.parse({
      'type': 'groupChatCallback',
      'clientMsgId': 10,
      'msgId': 25,
      'code': 100,
    });
    final read = ChatRealtimeEvent.parse({
      'type': 'groupChatCallback',
      'msgId': 25,
      'status': 'read',
    });

    expect(delivery.type, ChatRealtimeEventType.groupDelivery);
    expect(delivery.clientMessageId, 10);
    expect(delivery.messageId, 25);
    expect(read.type, ChatRealtimeEventType.readReceipt);
  });
}
