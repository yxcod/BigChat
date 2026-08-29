import '../core/parsing/json_value_parser.dart';

class GroupMemberModel {
  int groupId; // 群聊ID
  String userId; // 用户ID（字符串形式）
  int role; // 成员角色：0-普通成员 1-管理员 2-群主
  int joinTime; // 加入时间，时间戳
  int quitTime; // 退出时间时间戳，0 表示未退出
  int isQuit; // 是否退出：0-未退出 1-已退出
  String groupNickName; // 在群里的昵称
  String avatar; // 用户头像
  bool isMuted; // 是否被禁言
  String mutedBy; // 执行禁言的成员账号
  int mutedAt; // 禁言时间戳

  GroupMemberModel({
    this.groupId = 0,
    required this.userId,
    this.role = 0,
    this.joinTime = 0,
    this.quitTime = 0,
    this.isQuit = 0,
    this.groupNickName = '',
    this.avatar = '',
    this.isMuted = false,
    this.mutedBy = '',
    this.mutedAt = 0,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      groupId: JsonValueParser.intValue(json['groupId']),
      userId: JsonValueParser.stringValue(json['userId']),
      role: JsonValueParser.intValue(json['role']),
      joinTime: JsonValueParser.timestampMillis(json['joinTime']),
      quitTime: JsonValueParser.timestampMillis(json['quitTime']),
      isQuit: JsonValueParser.intValue(json['isQuit']),
      groupNickName: JsonValueParser.stringValue(json['groupNickName']),
      avatar: JsonValueParser.stringValue(json['avatar']),
      isMuted:
          JsonValueParser.intValue(json['isMuted']) == 1 ||
          json['isMuted'] == true,
      mutedBy: JsonValueParser.stringValue(json['mutedBy']),
      mutedAt: JsonValueParser.timestampMillis(json['mutedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'userId': userId,
      'role': role,
      'joinTime': joinTime,
      'quitTime': quitTime,
      'isQuit': isQuit,
      'groupNickName': groupNickName,
      'avatar': avatar,
      'isMuted': isMuted,
      'mutedBy': mutedBy,
      'mutedAt': mutedAt,
    };
  }
}
