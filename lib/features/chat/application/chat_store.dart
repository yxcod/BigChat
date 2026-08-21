import '../../../model/messageModel.dart';

class ChatStore {
  final Map<String, List<int>> _unreadMessages = {};
  final Map<String, List<Message>> _chatRecords = {};

  int addUnreadMessage(String conversationId, int messageId) {
    final messageIds = _unreadMessages.putIfAbsent(conversationId, () => []);
    if (!messageIds.contains(messageId)) {
      messageIds.add(messageId);
    }
    return messageIds.length;
  }

  List<int> unreadMessageIds(String conversationId) {
    return List<int>.unmodifiable(_unreadMessages[conversationId] ?? const []);
  }

  int unreadCount(String conversationId) {
    return _unreadMessages[conversationId]?.length ?? 0;
  }

  void clearUnreadMessages(String conversationId) {
    _unreadMessages.remove(conversationId);
  }

  bool addMessage(String conversationId, Message message) {
    final messages = _chatRecords.putIfAbsent(conversationId, () => []);
    if (messages.any((item) => item.msgId == message.msgId)) {
      return false;
    }
    messages.add(message);
    return true;
  }

  List<Message> messages(String conversationId) {
    return _chatRecords[conversationId] ?? const [];
  }

  int messageCount(String conversationId) {
    return _chatRecords[conversationId]?.length ?? 0;
  }

  Iterable<String> get conversationIds => _chatRecords.keys;

  List<Message> messageSnapshot(String conversationId) {
    return List<Message>.of(_chatRecords[conversationId] ?? const []);
  }

  void replaceMessages(String conversationId, List<Message> messages) {
    _chatRecords[conversationId] = messages;
  }

  void clearMessages(String conversationId) {
    _chatRecords.remove(conversationId);
  }

  void clearAllMessages() {
    _chatRecords.clear();
  }

  void markMessageAsRead(String conversationId, int messageId) {
    final messages = _chatRecords[conversationId];
    if (messages == null) return;
    for (final message in messages) {
      if (message.msgId == messageId) {
        message.isRead = true;
        message.status = MessageStatus.read;
        return;
      }
    }
  }

  void markAllIncomingMessagesAsRead(String conversationId) {
    final messages = _chatRecords[conversationId];
    if (messages == null) return;
    for (final message in messages) {
      if (!message.isMe) {
        message.isRead = true;
        message.status = MessageStatus.read;
      }
    }
  }

  void deleteMessage(String conversationId, int messageId) {
    _chatRecords[conversationId]?.removeWhere(
      (message) => message.msgId == messageId,
    );
  }
}
