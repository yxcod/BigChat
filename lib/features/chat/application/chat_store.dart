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

  void clearAllUnreadMessages() {
    _unreadMessages.clear();
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

  String? conversationIdForMessage(int messageId) {
    for (final entry in _chatRecords.entries) {
      if (entry.value.any((message) => message.msgId == messageId)) {
        return entry.key;
      }
    }
    return null;
  }

  void replaceMessages(String conversationId, List<Message> messages) {
    _chatRecords[conversationId] = messages;
  }

  void mergeMessages(String conversationId, List<Message> messages) {
    final merged = <int, Message>{
      for (final message in _chatRecords[conversationId] ?? const <Message>[])
        message.msgId: message,
    };
    for (final message in messages) {
      merged[message.msgId] = message;
    }
    final result = merged.values.toList()
      ..sort((left, right) {
        final byTime = left.timestamp.compareTo(right.timestamp);
        return byTime != 0 ? byTime : left.msgId.compareTo(right.msgId);
      });
    _chatRecords[conversationId] = result;
  }

  String? updateMessageStatus(int messageId, MessageStatus status) {
    for (final entry in _chatRecords.entries) {
      for (final message in entry.value) {
        if (message.msgId == messageId && message.isMe) {
          message.status = status;
          return entry.key;
        }
      }
    }
    return null;
  }

  String? reconcileMessageId(int clientMessageId, int serverMessageId) {
    for (final entry in _chatRecords.entries) {
      for (final message in entry.value) {
        if (message.msgId == clientMessageId && message.isMe) {
          message.msgId = serverMessageId;
          return entry.key;
        }
      }
    }
    return null;
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
