import '../core/parsing/json_value_parser.dart';

class GroupMessageModel {
  int code; // 响应码
  int groupId; // 群组ID
  List<MessageDetailModel> messages; // 消息列表

  GroupMessageModel({
    this.code = 0,
    this.groupId = 0,
    this.messages = const [],
  });

  factory GroupMessageModel.fromJson(Map<String, dynamic> json) {
    List<MessageDetailModel> messagesList = [];
    if (json['messages'] != null && json['messages'] is List) {
      messagesList = JsonValueParser.listValue(json['messages'])
          .map(JsonValueParser.mapValue)
          .whereType<Map<String, dynamic>>()
          .map(MessageDetailModel.fromJson)
          .toList();
    }

    return GroupMessageModel(
      code: JsonValueParser.intValue(json['code']),
      groupId: JsonValueParser.intValue(json['groupId']),
      messages: messagesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'groupId': groupId,
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }
}

class MessageDetailModel {
  int msgId; // 消息ID
  int groupId; // 群组ID
  String senderId; // 发送者ID
  int msgType; // 消息类型
  String msgContent; // 消息内容
  dynamic extendInfo; // 引用等扩展消息信息
  int fileSize; // 文件大小
  int sendTime; // 发送时间
  int isDeleted; // 是否删除
  int isRead; // 是否已读
  List<ReaderModel> readers; // 已读用户列表
  List<ReaderModel> unreaders; // 未读用户列表
  bool hasUnreadersField; // 后端是否明确返回未读列表

  MessageDetailModel({
    this.msgId = 0,
    this.groupId = 0,
    this.senderId = '',
    this.msgType = 0,
    this.msgContent = '',
    this.extendInfo,
    this.fileSize = 0,
    this.sendTime = 0,
    this.isDeleted = 0,
    this.isRead = 0,
    this.readers = const [],
    this.unreaders = const [],
    this.hasUnreadersField = false,
  });

  factory MessageDetailModel.fromJson(Map<String, dynamic> json) {
    List<ReaderModel> readersList = [];
    if (json['readers'] != null && json['readers'] is List) {
      readersList = JsonValueParser.listValue(json['readers'])
          .map(JsonValueParser.mapValue)
          .whereType<Map<String, dynamic>>()
          .map(ReaderModel.fromJson)
          .toList();
    }

    List<ReaderModel> unreadersList = [];
    if (json['unreaders'] != null && json['unreaders'] is List) {
      unreadersList = JsonValueParser.listValue(json['unreaders'])
          .map(JsonValueParser.mapValue)
          .whereType<Map<String, dynamic>>()
          .map(ReaderModel.fromJson)
          .toList();
    }

    return MessageDetailModel(
      msgId: JsonValueParser.intValue(json['msgId']),
      groupId: JsonValueParser.intValue(json['groupId']),
      senderId: JsonValueParser.stringValue(json['senderId']),
      msgType: JsonValueParser.intValue(json['msgType']),
      msgContent: JsonValueParser.stringValue(json['msgContent']),
      extendInfo: json['extendInfo'],
      fileSize: JsonValueParser.intValue(json['fileSize']),
      sendTime: JsonValueParser.timestampMillis(json['sendTime']),
      isDeleted: JsonValueParser.intValue(json['isDeleted']),
      isRead: JsonValueParser.intValue(json['isRead']),
      readers: readersList,
      unreaders: unreadersList,
      hasUnreadersField: json.containsKey('unreaders'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'msgId': msgId,
      'groupId': groupId,
      'senderId': senderId,
      'msgType': msgType,
      'msgContent': msgContent,
      'extendInfo': extendInfo,
      'fileSize': fileSize,
      'sendTime': sendTime,
      'isDeleted': isDeleted,
      'isRead': isRead,
      'readers': readers.map((reader) => reader.toJson()).toList(),
      'unreaders': unreaders.map((reader) => reader.toJson()).toList(),
    };
  }
}

class ReaderModel {
  String userId; // 用户ID
  int readTime; // 阅读时间

  ReaderModel({this.userId = '', this.readTime = 0});

  factory ReaderModel.fromJson(Map<String, dynamic> json) {
    return ReaderModel(
      userId: JsonValueParser.stringValue(json['userId']),
      readTime: JsonValueParser.timestampMillis(json['readTime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'readTime': readTime};
  }
}
