import 'friendInfoModel.dart';
import '../core/parsing/json_value_parser.dart';

class UserInfoModel {
  String? userName;
  String? nickName;
  String? avatar;
  String? signature;
  List<FriendInfoModel>? friendListData;
  UserInfoModel({
    required this.userName,
    required this.nickName,
    required this.avatar,
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
      signature: JsonValueParser.stringValue(json["signature"]),
      friendListData: friendList,
    ); //..friendListData = friendList;
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
