import 'package:flutter_base/features/chat/domain/chat_message_mapper.dart';
import 'package:flutter_base/model/groupMessageModel.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a private API record without losing sender metadata', () {
    final record = MessageModel(
      senderName: 'alice',
      receiverName: 'me',
      msgId: 12,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      content: 'hello',
      messageType: MessageType.image,
      messageStatus: MessageStatus.delivered,
      conversationId: 'alice_me',
    );

    final message = ChatMessageMapper.fromPrivateRecord(
      record,
      currentUserId: 'me',
    );

    expect(message.msgId, 12);
    expect(message.isMe, isFalse);
    expect(message.senderId, 'alice');
    expect(message.messageType, MessageType.image);
    expect(message.status, MessageStatus.delivered);
  });

  test('maps group read state for incoming and outgoing records', () {
    final outgoing = MessageDetailModel(
      msgId: 20,
      groupId: 5,
      senderId: 'me',
      msgContent: 'sent',
      msgType: 1,
      sendTime: DateTime.now().millisecondsSinceEpoch,
      readers: [ReaderModel(userId: 'alice')],
    );
    final incoming = MessageDetailModel(
      msgId: 21,
      groupId: 5,
      senderId: 'alice',
      msgContent: 'photo',
      msgType: 2,
      sendTime: DateTime.now().millisecondsSinceEpoch,
      readers: [ReaderModel(userId: 'me')],
    );

    final outgoingMessage = ChatMessageMapper.fromGroupRecord(
      outgoing,
      currentUserId: 'me',
      conversationId: '5',
    );
    final incomingMessage = ChatMessageMapper.fromGroupRecord(
      incoming,
      currentUserId: 'me',
      conversationId: '5',
    );

    expect(outgoingMessage.isMe, isTrue);
    expect(outgoingMessage.isRead, isTrue);
    expect(incomingMessage.isMe, isFalse);
    expect(incomingMessage.isRead, isTrue);
    expect(incomingMessage.messageType, MessageType.image);
    expect(incomingMessage.senderId, 'alice');
  });
}
