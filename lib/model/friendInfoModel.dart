import '../core/parsing/json_value_parser.dart';

class FriendInfoModel {
  String? userName;
  String? nickName;
  String? remarks;
  String? avatar;
  String? signature;
  bool? isOnline;
  FriendInfoModel({
    required this.userName,
    required this.nickName,
    required this.remarks,
    required this.avatar,
    required this.signature,
    required this.isOnline,
  });
  factory FriendInfoModel.formJSON(Map<String, dynamic> json) {
    return FriendInfoModel(
      userName: JsonValueParser.stringValue(json["userName"]),
      nickName: JsonValueParser.stringValue(json["nickName"]),
      remarks: JsonValueParser.stringValue(json["remark"]),
      avatar: JsonValueParser.stringValue(json["avatar"]),
      signature: JsonValueParser.stringValue(json["signature"]),
      isOnline: JsonValueParser.boolValue(json["onlineStatus"]),
    );
  }
}
