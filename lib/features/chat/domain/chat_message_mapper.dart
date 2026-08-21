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
      messageType: record.msgType == 2 ? MessageType.image : MessageType.text,
      status: MessageStatus.sent,
      senderId: record.senderId,
    );
  }
}
