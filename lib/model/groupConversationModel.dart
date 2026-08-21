import '../core/parsing/json_value_parser.dart';

class GroupConversationModel {
  int id; // 主键ID
  int groupId; // 群组唯一标识
  int updateTime; // 最后更新时间戳
  String lastSenderId; // 最后发送者ID
  String lastMsg; // 最后一条消息内容
  int unreadCount; // 未读数量

  GroupConversationModel({
    this.id = 0,
    this.groupId = 0,
    this.updateTime = 0,
    this.lastSenderId = '',
    this.lastMsg = '',
    this.unreadCount = 0,
  });

  factory GroupConversationModel.fromJson(Map<String, dynamic> json) {
    return GroupConversationModel(
      id: JsonValueParser.intValue(json['id']),
      groupId: JsonValueParser.intValue(json['groupId']),
      updateTime: JsonValueParser.timestampMillis(json['updateTime']),
      lastSenderId: JsonValueParser.stringValue(json['lastSenderId']),
      lastMsg: JsonValueParser.stringValue(json['lastMsg']),
      unreadCount: JsonValueParser.intValue(json['unreadCount']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupId': groupId,
      'updateTime': updateTime,
      'lastSenderId': lastSenderId,
      'lastMsg': lastMsg,
      'unreadCount': unreadCount,
    };
  }
}
