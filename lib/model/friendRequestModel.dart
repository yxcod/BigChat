import '../core/parsing/json_value_parser.dart';

enum RequestStatus { pending, accepted, rejected }

class FriendRequestModel {
  int? requestId;
  String? userName;
  String? nickName;
  String? verificationMessage;
  DateTime? requestTime;
  RequestStatus? status;

  FriendRequestModel({
    required this.requestId,
    required this.userName,
    required this.nickName,
    required this.verificationMessage,
    required this.requestTime,
    this.status = RequestStatus.pending,
  });

  factory FriendRequestModel.fromJSON(Map<String, dynamic> json) {
    return FriendRequestModel(
      requestId: JsonValueParser.intValue(json["id"]),
      userName: JsonValueParser.stringValue(json["fromUserId"]),
      nickName: JsonValueParser.stringValue(json["nickName"]),
      verificationMessage: JsonValueParser.stringValue(json["applyMsg"]),
      requestTime: json["createTime"] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              JsonValueParser.timestampMillis(json["createTime"]),
            )
          : DateTime.now(),
    );
  }
}

class RecentFriendModel {
  String? userName;
  String? nickName;
  int? addTime;
  String? remarks;

  RecentFriendModel({
    required this.userName,
    required this.nickName,
    required this.addTime,
    this.remarks,
  });

  factory RecentFriendModel.fromJSON(Map<String, dynamic> json) {
    return RecentFriendModel(
      userName: JsonValueParser.stringValue(json["userName"]),
      nickName: JsonValueParser.stringValue(json["nickName"]),
      addTime: JsonValueParser.timestampMillis(
        json["addTime"],
        fallback: DateTime.now().millisecondsSinceEpoch,
      ),
      remarks: JsonValueParser.stringValue(json["remarks"]),
    );
  }
}
