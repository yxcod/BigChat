class GroupMemberModel {
  int groupId; // 群聊ID
  String userId; // 用户ID（字符串形式）
  int role; // 成员角色：0-普通成员 1-管理员 2-群主
  int joinTime; // 加入时间，时间戳
  int quitTime; // 退出时间时间戳，0 表示未退出
  int isQuit; // 是否退出：0-未退出 1-已退出
  String groupNickName; // 在群里的昵称
  String avatar; // 用户头像

  GroupMemberModel({
    this.groupId = 0,
    required this.userId,
    this.role = 0,
    this.joinTime = 0,
    this.quitTime = 0,
    this.isQuit = 0,
    this.groupNickName = '',
    this.avatar = '',
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      groupId: json['groupId'] ?? 0,
      userId: json['userId'] ?? '',
      role: json['role'] ?? 0,
      joinTime: json['joinTime'] ?? 0,
      quitTime: json['quitTime'] ?? 0,
      isQuit: json['isQuit'] ?? 0,
      groupNickName: json['groupNickName'] ?? '',
      avatar: json['avatar'] ?? '',
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
    };
  }
}
