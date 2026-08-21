import '../core/parsing/json_value_parser.dart';

class GroupInfoModel {
  int groupId; // 群聊ID（主键）
  String groupName; // 群聊名称
  String groupAvatar; // 群头像URL
  String creatorId; // 创建人用户ID（字符串形式）
  String description; // 群聊描述（可为空）
  int maxMembers; // 最大成员数
  int isActive; // 是否有效：1-有效 0-解散
  int createdAt; // 创建时间（时间戳）
  int updatedAt; // 更新时间（时间戳）

  GroupInfoModel({
    this.groupId = 0,
    required this.groupName,
    this.groupAvatar = '',
    required this.creatorId,
    this.description = '',
    this.maxMembers = 200,
    this.isActive = 1,
    this.createdAt = 0,
    this.updatedAt = 0,
  });

  factory GroupInfoModel.fromJson(Map<String, dynamic> json) {
    return GroupInfoModel(
      groupId: JsonValueParser.intValue(json['groupId']),
      groupName: JsonValueParser.stringValue(json['groupName']),
      groupAvatar: JsonValueParser.stringValue(json['groupAvatar']),
      creatorId: JsonValueParser.stringValue(json['creatorId']),
      description: JsonValueParser.stringValue(json['description']),
      maxMembers: JsonValueParser.intValue(json['maxMembers'], fallback: 200),
      isActive: JsonValueParser.intValue(json['isActive'], fallback: 1),
      createdAt: JsonValueParser.timestampMillis(json['createdAt']),
      updatedAt: JsonValueParser.timestampMillis(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'groupAvatar': groupAvatar,
      'creatorId': creatorId,
      'description': description,
      'maxMembers': maxMembers,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
