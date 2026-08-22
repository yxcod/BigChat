import 'package:flutter_base/features/chat/application/chat_store.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatStore unread messages', () {
    test('deduplicates message IDs per conversation', () {
      final store = ChatStore();

      expect(store.addUnreadMessage('alice', 1), 1);
      expect(store.addUnreadMessage('alice', 1), 1);
      expect(store.addUnreadMessage('alice', 2), 2);
      expect(store.addUnreadMessage('bob', 1), 1);

      expect(store.unreadMessageIds('alice'), [1, 2]);
      expect(store.unreadCount('bob'), 1);

      store.clearUnreadMessages('alice');
      expect(store.unreadCount('alice'), 0);
    });
  });

  group('ChatStore messages', () {
    test('deduplicates, marks and deletes messages', () {
      final store = ChatStore();
      final incoming = _message(id: 1, isMe: false);
      final outgoing = _message(id: 2, isMe: true);

      expect(store.addMessage('alice', incoming), isTrue);
      expect(store.addMessage('alice', incoming), isFalse);
      expect(store.addMessage('alice', outgoing), isTrue);
      expect(store.messageCount('alice'), 2);
      expect(store.conversationIdForMessage(2), 'alice');

      store.markAllIncomingMessagesAsRead('alice');
      expect(incoming.isRead, isTrue);
      expect(incoming.status, MessageStatus.read);
      expect(outgoing.isRead, isFalse);

      store.markMessageAsRead('alice', 2);
      expect(outgoing.isRead, isTrue);
      expect(outgoing.status, MessageStatus.read);

      store.deleteMessage('alice', 1);
      expect(store.messages('alice').map((message) => message.msgId), [2]);
    });

    test('replaces and clears conversation records', () {
      final store = ChatStore();

      store.replaceMessages('alice', [_message(id: 3, isMe: false)]);
      store.replaceMessages('bob', [_message(id: 4, isMe: false)]);
      expect(store.messageCount('alice'), 1);

      store.clearMessages('alice');
      expect(store.messages('alice'), isEmpty);
      expect(store.messageCount('bob'), 1);

      store.clearAllMessages();
      expect(store.messages('bob'), isEmpty);
    });

    test('merges server history without dropping older local records', () {
      final store = ChatStore();
      store.replaceMessages('alice', [
        _message(id: 1, isMe: false, timestamp: 1000),
        _message(id: 2, isMe: true, timestamp: 2000),
      ]);

      store.mergeMessages('alice', [
        _message(id: 2, isMe: true, timestamp: 2000),
        _message(id: 3, isMe: false, timestamp: 3000),
      ]);

      expect(store.messages('alice').map((message) => message.msgId), [
        1,
        2,
        3,
      ]);
    });

    test('reconciles temporary group id and delivery status', () {
      final store = ChatStore();
      final outgoing = _message(id: 10, isMe: true);
      outgoing.status = MessageStatus.sending;
      store.addMessage('10001', outgoing);

      expect(store.reconcileMessageId(10, 99), '10001');
      expect(outgoing.msgId, 99);
      expect(store.updateMessageStatus(99, MessageStatus.sent), '10001');
      expect(outgoing.status, MessageStatus.sent);
    });
  });
}

Message _message({required int id, required bool isMe, int? timestamp}) {
  return Message(
    msgId: id,
    content: 'message $id',
    isMe: isMe,
    time: '12:00',
    isRead: false,
    conversationId: 'conversation',
    timestamp: timestamp,
  );
}
