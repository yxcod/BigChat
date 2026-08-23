import '../../../model/groupMessageModel.dart';
import '../../../model/messageModel.dart';
import 'chat_time_formatter.dart';

class ChatMessageMapper {
  const ChatMessageMapper._();

  static Message fromPrivateRecord(
    MessageModel record, {
    required String currentUserId,
  }) {
    return Message(
      msgId: record.msgId ?? 0,
      content: record.content ?? '',
      isMe: record.senderName == currentUserId,
      time: record.timestamp == null
          ? ''
          : ChatTimeFormatter.format(record.timestamp!),
      isRead: true,
      conversationId: record.conversationId ?? '',
      messageType: record.messageType ?? MessageType.text,
      status: record.messageStatus ?? MessageStatus.sent,
      senderId: record.senderName,
      timestamp: record.timestamp ?? 0,
    );
  }

  static Message fromGroupRecord(
    MessageDetailModel record, {
    required String currentUserId,
    required String conversationId,
  }) {
    final readUserIds = record.readers
        .map((reader) => reader.userId)
        .where((userId) => userId.isNotEmpty)
        .toSet();
    final isMe = record.senderId == currentUserId;

    return Message(
      msgId: record.msgId,
      content: record.msgContent,
      isMe: isMe,
      time: ChatTimeFormatter.format(record.sendTime),
      isRead: isMe
          ? readUserIds.isNotEmpty
          : readUserIds.contains(currentUserId),
      conversationId: conversationId,
      messageType: switch (record.msgType) {
        2 => MessageType.image,
        3 => MessageType.audio,
        4 => MessageType.video,
        _ => MessageType.text,
      },
      status: MessageStatus.sent,
      senderId: record.senderId,
      timestamp: record.sendTime,
    );
  }

  static Message rebindOwnership(
    Message message, {
    required String currentUserId,
  }) {
    return Message(
      msgId: message.msgId,
      content: message.content,
      isMe: message.senderId == currentUserId,
      time: message.time,
      isRead: message.isRead,
      conversationId: message.conversationId,
      messageType: message.messageType,
      status: message.status,
      senderId: message.senderId,
      timestamp: message.timestamp,
    );
  }
}
