import 'messageModel.dart';

class MessageResponseModel {
  int? msgId;
  MessageStatus? status;

  MessageResponseModel({
    required this.msgId,
    required this.status,
  });

  factory MessageResponseModel.fromJSON(Map<String, dynamic> json) {
    // 解析消息状态
    MessageStatus? status;
    try {
      if (json["status"] != null) {
        final statusStr = json["status"];
        if (statusStr is String) {
          status = MessageStatus.values.firstWhere(
            (e) => e.name == statusStr.toLowerCase(),
            orElse: () => MessageStatus.sent,
          );
        } else if (statusStr is int) {
          status = MessageStatus.values[statusStr];
        }
      }
    } catch (e) {
      status = MessageStatus.sent;
    }

    return MessageResponseModel(
      msgId: json["msgId"] ?? 0,
      status: status ?? MessageStatus.sent,
    );
  }

  Map<String, dynamic> toJSON() {
    return {
      "msgId": msgId,
      "status": status?.name,
    };
  }
}

// 对应JSON示例
// {
//   "msgId": 123456,
//   "status": "read"
// }
