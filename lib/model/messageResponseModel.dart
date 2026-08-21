import 'messageModel.dart';
import '../core/parsing/json_value_parser.dart';

class MessageResponseModel {
  int? msgId;
  MessageStatus? status;

  MessageResponseModel({required this.msgId, required this.status});

  factory MessageResponseModel.fromJSON(Map<String, dynamic> json) {
    return MessageResponseModel(
      msgId: JsonValueParser.intValue(json["msgId"]),
      status: JsonValueParser.enumValue(
        json["status"],
        MessageStatus.values,
        fallback: MessageStatus.sent,
      ),
    );
  }

  Map<String, dynamic> toJSON() {
    return {"msgId": msgId, "status": status?.name};
  }
}

// 对应JSON示例
// {
//   "msgId": 123456,
//   "status": "read"
// }
