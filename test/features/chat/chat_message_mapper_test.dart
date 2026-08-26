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

  test('rebinds cached group ownership to the currently logged-in user', () {
    final cachedForAlice = Message(
      msgId: 30,
      content: 'cached',
      isMe: true,
      time: '10:00',
      isRead: false,
      conversationId: '5',
      senderId: 'alice',
      timestamp: 1000,
    );

    final viewedByBob = ChatMessageMapper.rebindOwnership(
      cachedForAlice,
      currentUserId: 'bob',
    );

    expect(viewedByBob.isMe, isFalse);
    expect(viewedByBob.senderId, 'alice');
    expect(viewedByBob.timestamp, 1000);
  });

  test('rebinds ownership without stripping privacy metadata', () {
    final privacyMessage = Message(
      msgId: 33,
      content: '仅保存在内存中的内容',
      isMe: false,
      time: '10:00',
      isRead: false,
      conversationId: '5',
      senderId: 'alice',
      timestamp: 1000,
      isPrivacy: true,
      privacyReadDelaySeconds: 25,
      privacyUnreadDelaySeconds: 240,
    );

    final rebound = ChatMessageMapper.rebindOwnership(
      privacyMessage,
      currentUserId: 'bob',
    );

    expect(rebound.isPrivacy, isTrue);
    expect(rebound.privacyReadDelaySeconds, 25);
    expect(rebound.privacyUnreadDelaySeconds, 240);
  });

  test('maps server voice type to an audio message', () {
    final record = MessageDetailModel(
      msgId: 31,
      groupId: 5,
      senderId: 'alice',
      msgContent: '{"audioName":"voice.m4a","durationMs":2400}',
      msgType: 3,
      sendTime: DateTime.now().millisecondsSinceEpoch,
    );

    final message = ChatMessageMapper.fromGroupRecord(
      record,
      currentUserId: 'me',
      conversationId: '5',
    );

    expect(message.messageType, MessageType.audio);
    expect(message.senderId, 'alice');
  });

  test('maps server file type to a file message', () {
    final record = MessageDetailModel(
      msgId: 32,
      groupId: 5,
      senderId: 'alice',
      msgContent: '{"storedName":"a.pdf","originalName":"资料.pdf"}',
      msgType: 5,
      sendTime: DateTime.now().millisecondsSinceEpoch,
    );

    final message = ChatMessageMapper.fromGroupRecord(
      record,
      currentUserId: 'me',
      conversationId: '5',
    );

    expect(message.messageType, MessageType.file);
  });
}
