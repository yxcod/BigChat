import '../core/parsing/json_value_parser.dart';

class FriendInfoModel {
  String? userName;
  String? nickName;
  String? remarks;
  String? avatar;
  int modifyTime;
  int gender;
  String region;
  String? signature;
  bool? isOnline;
  FriendInfoModel({
    required this.userName,
    required this.nickName,
    required this.remarks,
    required this.avatar,
    this.modifyTime = 0,
    this.gender = 0,
    this.region = '',
    required this.signature,
    required this.isOnline,
  });
  factory FriendInfoModel.formJSON(Map<String, dynamic> json) {
    return FriendInfoModel(
      userName: JsonValueParser.stringValue(json["userName"]),
      nickName: JsonValueParser.stringValue(json["nickName"]),
      remarks: JsonValueParser.stringValue(json["remark"]),
      avatar: JsonValueParser.stringValue(json["avatar"]),
      modifyTime: JsonValueParser.timestampMillis(json['modifyTime']),
      gender: JsonValueParser.intValue(json["gender"], fallback: 0),
      region: JsonValueParser.stringValue(json["region"]),
      signature: JsonValueParser.stringValue(json["signature"]),
      isOnline: JsonValueParser.boolValue(json["onlineStatus"]),
    );
  }

  Map<String, dynamic> toJson() => {
    'userName': userName,
    'nickName': nickName,
    'remark': remarks,
    'avatar': avatar,
    'modifyTime': modifyTime,
    'gender': gender,
    'region': region,
    'signature': signature,
    'onlineStatus': isOnline,
  };
}
