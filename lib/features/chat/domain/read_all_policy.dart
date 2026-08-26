import '../../../model/messageModel.dart';

class PendingReadAck {
  final int messageId;
  final String senderId;
  final bool isPrivacy;

  const PendingReadAck({
    required this.messageId,
    required this.senderId,
    required this.isPrivacy,
  });
}

/// Builds a de-duplicated read plan from the explicit unread-id cache and the
/// in-memory message state. The id cache is authoritative for messages loaded
/// from the unread API, whose legacy `isRead` value may not be reliable.
List<PendingReadAck> pendingReadAcks({
  required Iterable<Message> messages,
  required Iterable<int> unreadMessageIds,
  required String fallbackSenderId,
}) {
  final messagesById = <int, Message>{
    for (final message in messages)
      if (!message.isMe && message.msgId > 0) message.msgId: message,
  };
  final pendingIds = <int>{
    ...unreadMessageIds.where((id) => id > 0),
    ...messagesById.values
        .where((message) => !message.isRead)
        .map((message) => message.msgId),
  }.toList()..sort();

  return pendingIds
      .map((messageId) {
        final message = messagesById[messageId];
        final senderId = message?.senderId?.trim() ?? '';
        return PendingReadAck(
          messageId: messageId,
          senderId: senderId.isEmpty ? fallbackSenderId : senderId,
          isPrivacy: message?.isPrivacy == true,
        );
      })
      .toList(growable: false);
}
