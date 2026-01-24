class GroupInfoModel {
  int groupId;        // 群聊ID（主键）
  String groupName;   // 群聊名称
  String groupAvatar; // 群头像URL
  String creatorId;   // 创建人用户ID（字符串形式）
  String description; // 群聊描述（可为空）
  int maxMembers;     // 最大成员数
  int isActive;       // 是否有效：1-有效 0-解散
  int createdAt;      // 创建时间（时间戳）
  int updatedAt;      // 更新时间（时间戳）

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
      groupId: json['groupId'] ?? 0,
      groupName: json['groupName'] ?? '',
      groupAvatar: json['groupAvatar'] ?? '',
      creatorId: json['creatorId'] ?? '',
      description: json['description'] ?? '',
      maxMembers: json['maxMembers'] ?? 200,
      isActive: json['isActive'] ?? 1,
      createdAt: json['createdAt'] ?? 0,
      updatedAt: json['updatedAt'] ?? 0,
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
