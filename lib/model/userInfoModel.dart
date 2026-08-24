import 'friendInfoModel.dart';
import '../core/parsing/json_value_parser.dart';

class UserInfoModel {
  String? userName;
  String? nickName;
  String? avatar;
  int gender;
  String region;
  String? signature;
  List<FriendInfoModel>? friendListData;
  UserInfoModel({
    required this.userName,
    required this.nickName,
    required this.avatar,
    this.gender = 0,
    this.region = '',
    required this.signature,
    required this.friendListData,
  });
  factory UserInfoModel.formJSON(Map<String, dynamic> json) {
    // 解析friendListData数组
    List<FriendInfoModel>? friendList;
    if (json["friendListData"] != null) {
      friendList = [];
      // 确保friendListData是一个List类型
      for (final item in JsonValueParser.listValue(json["friendListData"])) {
        final friendJson = JsonValueParser.mapValue(item);
        if (friendJson != null) {
          friendList.add(FriendInfoModel.formJSON(friendJson));
        }
      }
    }
    return UserInfoModel(
      userName: JsonValueParser.stringValue(json["userName"]),
      nickName: JsonValueParser.stringValue(json["nickName"]),
      avatar: JsonValueParser.stringValue(json["avatar"]),
      gender: JsonValueParser.intValue(json["gender"], fallback: 0),
      region: JsonValueParser.stringValue(json["region"]),
      signature: JsonValueParser.stringValue(json["signature"]),
      friendListData: friendList,
    ); //..friendListData = friendList;
  }
}

String userGenderLabel(int gender) {
  switch (gender) {
    case 1:
      return '男';
    case 2:
      return '女';
    default:
      return '保密';
  }
}

//对应json
// {
//   "userName": "user001",
//   "nickName": "张三",
//   "avater": "https://example.com/avatar.jpg",
//   "signature": "个人签名",
//   "friendListData": [
//     {
//       "userName": "friend001",
//       "nickName": "李四",
//       "remarks": "老李",
//       "avater": "https://example.com/friend1.jpg",
//       "signature": "好友签名1"
//     },
//     {
//       "userName": "friend002",
//       "nickName": "王五",
//       "remarks": "",
//       "avater": "https://example.com/friend2.jpg",
//       "signature": "好友签名2"
//     }
//   ]
// }
