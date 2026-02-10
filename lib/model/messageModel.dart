import 'dart:convert';

// 消息类型枚举
enum MessageType { text, image, video, audio, file, location, system }

// 消息状态枚举
enum MessageStatus { sending, sent, delivered, read, failed }

class MessageModel {
  String? senderName;
  String? receiverName;
  int? msgId;
  int? timestamp;
  String? content;
  MessageType? messageType;
  MessageStatus? messageStatus;
  String? conversationId;

  MessageModel({
    required this.senderName,
    required this.receiverName,
    required this.msgId,
    required this.timestamp,
    required this.content,
    required this.messageType,
    required this.messageStatus,
    required this.conversationId,
  });

  factory MessageModel.fromJSON(Map<String, dynamic> json) {
    // 解析消息类型
    MessageType? messageType;
    try {
      if (json["messageType"] != null) {
        final typeStr = json["messageType"];
        if (typeStr is int) {
          messageType = MessageType.values[typeStr];
        }
      }
    } catch (e) {
      messageType = MessageType.text;
    }

    // 解析消息状态
    MessageStatus? messageStatus;
    try {
      if (json["messageStatus"] != null) {
        final statusStr = json["messageStatus"];
        if (statusStr is int) {
          messageStatus = MessageStatus.values[statusStr];
        }
      }
    } catch (e) {
      messageStatus = MessageStatus.sent;
    }

    return MessageModel(
      senderName: json["senderName"] ?? "",
      receiverName: json["receiverName"] ?? "",
      timestamp: json["timestamp"] ?? DateTime.now().millisecondsSinceEpoch,
      msgId: json["msgId"],
      content: json["content"] ?? "",
      messageType: messageType ?? MessageType.text,
      messageStatus: messageStatus ?? MessageStatus.sent,
      conversationId: json["conversationId"] ?? "",
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
    };
  }

  @override
  String toString() {
    return json.encode(toJSON());
  }
}

class Message {
  final int msgId;
  final String content;
  final bool isMe;
  final String time;
  final MessageType messageType;
  bool isRead;
  MessageStatus status;
  final String conversationId;
  final String? senderId;

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
  });

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
    };
  }

  // 反序列化方法：从Map<String, dynamic>创建Message对象
  factory Message.fromJSON(Map<String, dynamic> json) {
    return Message(
      msgId: json['msgId'] ?? 0,
      content: json['content'] ?? '',
      isMe: json['isMe'] ?? false,
      time: json['time'] ?? '',
      isRead: json['isRead'] ?? false,
      conversationId: json['conversationId'] ?? '',
      messageType: MessageType.values[json['messageType'] ?? 0],
      status: MessageStatus.values[json['status'] ?? 0],
      senderId: json['senderId'],
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
