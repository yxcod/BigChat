import 'dart:convert';
import '../core/parsing/json_value_parser.dart';

// 消息类型枚举
enum MessageType { text, image, video, audio, file, location, system }

// 消息状态枚举
enum MessageStatus { sending, sent, delivered, read, failed }

class MessageQuote {
  const MessageQuote({
    required this.messageId,
    required this.senderId,
    required this.senderLabel,
    required this.preview,
    required this.messageType,
  });

  final int messageId;
  final String senderId;
  final String senderLabel;
  final String preview;
  final MessageType messageType;

  Map<String, dynamic> toJson() => {
    'messageId': messageId,
    'senderId': senderId,
    'senderLabel': senderLabel,
    'preview': preview,
    'messageType': messageType.name,
  };

  factory MessageQuote.fromJson(Map<String, dynamic> json) {
    return MessageQuote(
      messageId: JsonValueParser.intValue(json['messageId']),
      senderId: JsonValueParser.stringValue(json['senderId']),
      senderLabel: JsonValueParser.stringValue(json['senderLabel']),
      preview: JsonValueParser.stringValue(json['preview']),
      messageType: JsonValueParser.enumValue(
        json['messageType'],
        MessageType.values,
        fallback: MessageType.text,
      ),
    );
  }

  static MessageQuote? fromExtendInfo(dynamic value) {
    try {
      dynamic decoded = value;
      if (decoded is String) {
        final normalized = decoded.trim();
        if (normalized.isEmpty || normalized == '无') return null;
        decoded = jsonDecode(normalized);
      }
      if (decoded is! Map) return null;
      final root = Map<String, dynamic>.from(decoded);
      final quote = root['quote'];
      if (quote is! Map) return null;
      return MessageQuote.fromJson(Map<String, dynamic>.from(quote));
    } catch (_) {
      return null;
    }
  }

  String encodeExtendInfo() => jsonEncode({'quote': toJson()});
}

bool isFriendVerificationExtendInfo(dynamic value) {
  try {
    dynamic decoded = value;
    if (decoded is String) {
      final normalized = decoded.trim();
      if (normalized.isEmpty || normalized == '无') return false;
      decoded = jsonDecode(normalized);
    }
    if (decoded is! Map) return false;
    return decoded['kind']?.toString() == 'friend_verification';
  } catch (_) {
    return false;
  }
}

class MessageMention {
  const MessageMention({required this.userId, required this.label});

  final String userId;
  final String label;

  Map<String, dynamic> toJson() => {'userId': userId, 'label': label};

  factory MessageMention.fromJson(Map<String, dynamic> json) {
    return MessageMention(
      userId: JsonValueParser.stringValue(json['userId']),
      label: JsonValueParser.stringValue(json['label']),
    );
  }
}

class GroupSystemEvent {
  const GroupSystemEvent({
    required this.kind,
    required this.userId,
    required this.nickname,
    this.inviterId = '',
    this.inviterNickname = '',
  });

  final String kind;
  final String userId;
  final String nickname;
  final String inviterId;
  final String inviterNickname;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'userId': userId,
    'nickname': nickname,
    'inviterId': inviterId,
    'inviterNickname': inviterNickname,
  };

  factory GroupSystemEvent.fromJson(Map<String, dynamic> json) {
    return GroupSystemEvent(
      kind: JsonValueParser.stringValue(json['kind']),
      userId: JsonValueParser.stringValue(json['userId']),
      nickname: JsonValueParser.stringValue(json['nickname']),
      inviterId: JsonValueParser.stringValue(json['inviterId']),
      inviterNickname: JsonValueParser.stringValue(json['inviterNickname']),
    );
  }
}

class MessageExtensions {
  const MessageExtensions({
    this.quote,
    this.mentions = const [],
    this.groupSystemEvent,
  });

  final MessageQuote? quote;
  final List<MessageMention> mentions;
  final GroupSystemEvent? groupSystemEvent;

  static MessageExtensions fromExtendInfo(dynamic value) {
    try {
      dynamic decoded = value;
      if (decoded is String) {
        final normalized = decoded.trim();
        if (normalized.isEmpty || normalized == '无') {
          return const MessageExtensions();
        }
        decoded = jsonDecode(normalized);
      }
      if (decoded is! Map) return const MessageExtensions();
      final root = Map<String, dynamic>.from(decoded);
      final quote = root['quote'] is Map
          ? MessageQuote.fromJson(Map<String, dynamic>.from(root['quote']))
          : null;
      final mentions = root['mentions'] is List
          ? (root['mentions'] as List)
                .whereType<Map>()
                .map(
                  (item) =>
                      MessageMention.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((mention) => mention.userId.isNotEmpty)
                .toList(growable: false)
          : const <MessageMention>[];
      final systemEvent = root['kind'] == 'group_member_joined'
          ? GroupSystemEvent.fromJson(root)
          : null;
      return MessageExtensions(
        quote: quote,
        mentions: mentions,
        groupSystemEvent: systemEvent,
      );
    } catch (_) {
      return const MessageExtensions();
    }
  }

  String encode() {
    final result = <String, dynamic>{};
    if (quote != null) result['quote'] = quote!.toJson();
    if (mentions.isNotEmpty) {
      result['mentions'] = mentions.map((mention) => mention.toJson()).toList();
    }
    if (groupSystemEvent != null) result.addAll(groupSystemEvent!.toJson());
    return jsonEncode(result);
  }
}

String messageQuotePreview(Message message) {
  final value = switch (message.messageType) {
    MessageType.image => '[图片]',
    MessageType.video => '[视频]',
    MessageType.audio => '[语音]',
    MessageType.file => '[文件]',
    MessageType.location => '[位置]',
    MessageType.system => '[系统消息]',
    MessageType.text => message.content.trim(),
  };
  if (value.length <= 48) return value;
  return '${value.substring(0, 48)}…';
}

class MessageModel {
  String? senderName;
  String? receiverName;
  int? msgId;
  int? timestamp;
  String? content;
  MessageType? messageType;
  MessageStatus? messageStatus;
  String? conversationId;
  dynamic extendInfo;

  MessageModel({
    required this.senderName,
    required this.receiverName,
    required this.msgId,
    required this.timestamp,
    required this.content,
    required this.messageType,
    required this.messageStatus,
    required this.conversationId,
    this.extendInfo,
  });

  factory MessageModel.fromJSON(Map<String, dynamic> json) {
    return MessageModel(
      senderName: JsonValueParser.stringValue(json["senderName"]),
      receiverName: JsonValueParser.stringValue(json["receiverName"]),
      timestamp: JsonValueParser.timestampMillis(
        json["timestamp"],
        fallback: DateTime.now().millisecondsSinceEpoch,
      ),
      msgId: JsonValueParser.intValue(json["msgId"]),
      content: JsonValueParser.stringValue(json["content"]),
      messageType: JsonValueParser.enumValue(
        json["messageType"],
        MessageType.values,
        fallback: MessageType.text,
      ),
      messageStatus: JsonValueParser.enumValue(
        json["messageStatus"],
        MessageStatus.values,
        fallback: MessageStatus.sent,
      ),
      conversationId: JsonValueParser.stringValue(json["conversationId"]),
      extendInfo: json['extendInfo'],
    );
  }

  Map<String, dynamic> toJSON() {
    return {
      "senderName": senderName,
      "receiverName": receiverName,
      "timestamp": timestamp,
      "content": content,
      "messageType": messageType?.name,
      "messageStatus": messageStatus?.name,
      "conversationId": conversationId,
      "extendInfo": extendInfo,
    };
  }

  @override
  String toString() {
    return json.encode(toJSON());
  }
}

class Message {
  int msgId;
  final String content;
  final bool isMe;
  final String time;
  final MessageType messageType;
  bool isRead;
  MessageStatus status;
  final String conversationId;
  final String? senderId;
  final int timestamp;
  final MessageQuote? quote;
  final List<MessageMention> mentions;
  final GroupSystemEvent? groupSystemEvent;
  final bool isFriendVerification;
  final bool isPrivacy;
  final int privacyReadDelaySeconds;
  final int privacyUnreadDelaySeconds;

  Message({
    required this.msgId,
    required this.content,
    required this.isMe,
    required this.time,
    required this.isRead,
    required this.conversationId,
    this.messageType = MessageType.text,
    this.status = MessageStatus.sent,
    this.senderId,
    int? timestamp,
    this.quote,
    this.mentions = const [],
    this.groupSystemEvent,
    this.isFriendVerification = false,
    this.isPrivacy = false,
    this.privacyReadDelaySeconds = 10,
    this.privacyUnreadDelaySeconds = 180,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  Message withQuote(MessageQuote value) {
    return Message(
      msgId: msgId,
      content: content,
      isMe: isMe,
      time: time,
      isRead: isRead,
      conversationId: conversationId,
      messageType: messageType,
      status: status,
      senderId: senderId,
      timestamp: timestamp,
      quote: value,
      mentions: mentions,
      groupSystemEvent: groupSystemEvent,
      isFriendVerification: isFriendVerification,
      isPrivacy: isPrivacy,
      privacyReadDelaySeconds: privacyReadDelaySeconds,
      privacyUnreadDelaySeconds: privacyUnreadDelaySeconds,
    );
  }

  // 序列化方法：将Message对象转换为Map<String, dynamic>
  Map<String, dynamic> toJSON() {
    return {
      'msgId': msgId,
      'content': content,
      'isMe': isMe,
      'time': time,
      'messageType': messageType.index,
      'isRead': isRead,
      'status': status.index,
      'conversationId': conversationId,
      'senderId': senderId,
      'timestamp': timestamp,
      'quote': quote?.toJson(),
      'mentions': mentions.map((mention) => mention.toJson()).toList(),
      'groupSystemEvent': groupSystemEvent?.toJson(),
      'isFriendVerification': isFriendVerification,
      'isPrivacy': isPrivacy,
      'privacyReadDelaySeconds': privacyReadDelaySeconds,
      'privacyUnreadDelaySeconds': privacyUnreadDelaySeconds,
    };
  }

  // 反序列化方法：从Map<String, dynamic>创建Message对象
  factory Message.fromJSON(Map<String, dynamic> json) {
    return Message(
      msgId: JsonValueParser.intValue(json['msgId']),
      content: JsonValueParser.stringValue(json['content']),
      isMe: JsonValueParser.boolValue(json['isMe']),
      time: JsonValueParser.stringValue(json['time']),
      isRead: JsonValueParser.boolValue(json['isRead']),
      conversationId: JsonValueParser.stringValue(json['conversationId']),
      messageType: JsonValueParser.enumValue(
        json['messageType'],
        MessageType.values,
        fallback: MessageType.text,
      ),
      status: JsonValueParser.enumValue(
        json['status'],
        MessageStatus.values,
        fallback: MessageStatus.sent,
      ),
      senderId: json['senderId'] == null
          ? null
          : JsonValueParser.stringValue(json['senderId']),
      timestamp: JsonValueParser.timestampMillis(json['timestamp']),
      quote: json['quote'] is Map
          ? MessageQuote.fromJson(Map<String, dynamic>.from(json['quote']))
          : null,
      mentions: json['mentions'] is List
          ? (json['mentions'] as List)
                .whereType<Map>()
                .map(
                  (item) =>
                      MessageMention.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
      groupSystemEvent: json['groupSystemEvent'] is Map
          ? GroupSystemEvent.fromJson(
              Map<String, dynamic>.from(json['groupSystemEvent']),
            )
          : null,
      isFriendVerification: JsonValueParser.boolValue(
        json['isFriendVerification'],
      ),
      isPrivacy: JsonValueParser.boolValue(json['isPrivacy']),
      privacyReadDelaySeconds: JsonValueParser.intValue(
        json['privacyReadDelaySeconds'],
        fallback: 10,
      ),
      privacyUnreadDelaySeconds: JsonValueParser.intValue(
        json['privacyUnreadDelaySeconds'],
        fallback: 180,
      ),
    );
  }
}
// 对应JSON示例
// {
//   "senderName": "user001",
//   "receiverName": "friend001",
//   "timestamp": 1736380800000,
//   "content": "Hello, how are you?",
//   "messageType": "text",
//   "messageStatus": "read",
//   "conversationId": "conv_001"
// }

// 图片消息示例
// {
//   "senderName": "user001",
//   "receiverName": "friend001",
//   "timestamp": 1736380800000,
//   "content": "https://example.com/image.jpg",
//   "messageType": "image",
//   "messageStatus": "sent",
//   "conversationId": "conv_001"
// }

// 语音消息示例
// {
//   "senderName": "user001",
//   "receiverName": "friend001",
//   "timestamp": 1736380800000,
//   "content": "https://example.com/audio.mp3",
//   "messageType": "audio",
//   "messageStatus": "delivered",
//   "conversationId": "conv_001"
// }
