import 'dart:convert';
import '../core/parsing/json_value_parser.dart';

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
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

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
