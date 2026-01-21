class ConversationModel {
  String convId;
  int convType;
  String user1Id;
  String user2Id;
  String groupId;
  String? lastMsg;
  String lastMsgId;
  String lastSenderId;
  int unreadCount;
  int updateTime;
  int user2isValid;
  int user1isVaild;

  ConversationModel({
    required this.convId,
    required this.convType,
    required this.user1Id,
    required this.user2Id,
    required this.groupId,
    this.lastMsg,
    required this.lastMsgId,
    required this.lastSenderId,
    required this.unreadCount,
    required this.updateTime,
    required this.user2isValid,
    required this.user1isVaild,
  });

  factory ConversationModel.formJSON(Map<String, dynamic> json) {
    return ConversationModel(
      convId: json['convId'] ?? '',
      convType: json['convType'] ?? 1,
      user1Id: json['user1Id'] ?? '',
      user2Id: json['user2Id'] ?? '',
      groupId: json['groupId'] ?? '',
      lastMsg: json['lastMsg'],
      lastMsgId: json['lastMsgId'] ?? '',
      lastSenderId: json['lastSenderId'] ?? '',
      unreadCount: json['unreadCount'] ?? 0,
      updateTime: json['updateTime'] ?? 11111,
      user2isValid: json['user2isValid'] ?? 0,
      user1isVaild: json['user1isVaild'] ?? 0,
    );
  }
}

// 对应数据库字段说明：
// convId - 会话唯一标识，主键 (varchar(32))
// convType - 会话类型：1-单聊，2-群聊 (tinyint)
// user1Id - 单聊-用户A/群聊-群主ID (varchar(32))
// user2Id - 单聊-用户B，群聊为空 (varchar(32))
// groupId - 群聊-关联群表ID，单聊为空 (varchar(32))
// lastMsg - 会话最新一条消息内容 (text)
// lastMsgId - 最新消息ID，关联消息表 (varchar(32))
// lastSenderId - 最新消息发送者ID (varchar(32))
// unreadCount - 未读消息数 (int)
// updateTime - 会话最后更新时间 (bigint unsigned)
// user2isValid - 用户2是否删除了会话：1-正常，0-已删除 (tinyint)
// user1isVaild - 用户1是否删除了会话：1-是，0-否 (tinyint)
