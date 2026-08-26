import 'package:flutter_base/features/chat/domain/read_all_policy.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Message message(
    int id, {
    bool isMe = false,
    bool isRead = false,
    bool isPrivacy = false,
    String? senderId = 'alice',
  }) {
    return Message(
      msgId: id,
      content: 'message $id',
      isMe: isMe,
      time: '10:00',
      isRead: isRead,
      conversationId: 'conversation',
      senderId: senderId,
      isPrivacy: isPrivacy,
    );
  }

  test(
    'combines cached ids and unread incoming messages without duplicates',
    () {
      final result = pendingReadAcks(
        messages: [
          message(1, isRead: true),
          message(2, isPrivacy: true),
          message(3, isMe: true),
        ],
        unreadMessageIds: [1, 2, 4],
        fallbackSenderId: 'fallback',
      );

      expect(result.map((item) => item.messageId), [1, 2, 4]);
      expect(result[1].isPrivacy, isTrue);
      expect(result[2].senderId, 'fallback');
    },
  );

  test(
    'ignores already-read and outgoing messages outside unread id cache',
    () {
      final result = pendingReadAcks(
        messages: [
          message(10, isRead: true),
          message(11, isMe: true),
          message(12, senderId: null),
        ],
        unreadMessageIds: const [],
        fallbackSenderId: 'peer',
      );

      expect(result.map((item) => item.messageId), [12]);
      expect(result.single.senderId, 'peer');
    },
  );
}
