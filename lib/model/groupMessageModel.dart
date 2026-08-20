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
      messagesList = (json['messages'] as List)
          .map((message) => MessageDetailModel.fromJson(message))
          .toList();
    }

    return GroupMessageModel(
      code: json['code'] ?? 0,
      groupId: json['groupId'] ?? 0,
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
      readersList = (json['readers'] as List)
          .map((reader) => ReaderModel.fromJson(reader))
          .toList();
    }

    List<ReaderModel> unreadersList = [];
    if (json['unreaders'] != null && json['unreaders'] is List) {
      unreadersList = (json['unreaders'] as List)
          .map((reader) => ReaderModel.fromJson(reader))
          .toList();
    }

    return MessageDetailModel(
      msgId: json['msgId'] ?? 0,
      groupId: json['groupId'] ?? 0,
      senderId: json['senderId'] ?? '',
      msgType: json['msgType'] ?? 0,
      msgContent: json['msgContent'] ?? '',
      fileSize: json['fileSize'] ?? 0,
      sendTime: json['sendTime'] ?? 0,
      isDeleted: json['isDeleted'] ?? 0,
      isRead: json['isRead'] ?? 0,
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
      userId: json['userId'] ?? '',
      readTime: json['readTime'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'userId': userId, 'readTime': readTime};
  }
}
