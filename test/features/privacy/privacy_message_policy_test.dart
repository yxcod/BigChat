import 'package:flutter_base/features/privacy/domain/privacy_message_policy.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only unacknowledged incoming privacy messages require read acks', () {
    Message message(int id, {bool privacy = true, bool isMe = false}) {
      return Message(
        msgId: id,
        content: 'message $id',
        isMe: isMe,
        time: '10:00',
        isRead: false,
        conversationId: 'group:5',
        senderId: 'alice',
        isPrivacy: privacy,
      );
    }

    final pending = privacyMessagesAwaitingReadAck(
      [
        message(1),
        message(2),
        message(3, privacy: false),
        message(4, isMe: true),
      ],
      {2},
    );

    expect(pending.map((item) => item.msgId), [1]);
  });
}
