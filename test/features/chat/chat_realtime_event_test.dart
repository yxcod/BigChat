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
      'clientMsgId': 10,
      'msgId': 25,
      'status': 'read',
    });

    expect(delivery.type, ChatRealtimeEventType.groupDelivery);
    expect(delivery.clientMessageId, 10);
    expect(delivery.messageId, 25);
    expect(read.type, ChatRealtimeEventType.readReceipt);
  });

  test('parses a group read watermark acknowledgement', () {
    final event = ChatRealtimeEvent.parse({
      'type': 'groupChatReadCallback',
      'code': 100,
      'groupId': '42',
      'reader': 'bob',
      'readThroughMsgId': '99',
    });

    expect(event.type, ChatRealtimeEventType.groupReadReceipt);
    expect(event.groupId, 42);
    expect(event.readerId, 'bob');
    expect(event.readThroughMessageId, 99);
  });

  test('parses a group history deletion notification', () {
    final event = ChatRealtimeEvent.parse({
      'type': 'groupChatHistoryDeleted',
      'groupId': '42',
      'operatorId': 'owner',
      'message': '群主已删除当前群聊的全部聊天记录',
    });

    expect(event.type, ChatRealtimeEventType.groupHistoryDeleted);
    expect(event.groupId, 42);
  });

  test('parses group membership management events', () {
    final removed = ChatRealtimeEvent.parse({
      'type': 'groupMemberRemoved',
      'groupId': '1001',
    });
    final roleUpdated = ChatRealtimeEvent.parse({
      'type': 'groupMemberRoleUpdated',
      'groupId': 1001,
      'role': 1,
    });

    expect(removed.type, ChatRealtimeEventType.groupMemberRemoved);
    expect(removed.groupId, 1001);
    expect(roleUpdated.type, ChatRealtimeEventType.groupMemberRoleUpdated);
  });
}
