import 'friendInfoModel.dart';

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
      if (json["friendListData"] is List) {
        for (var item in json["friendListData"]) {
          if (item is Map<String, dynamic>) {
            friendList.add(FriendInfoModel.formJSON(item));
          }
        }
      }
    }
    return UserInfoModel(
      userName: json["userName"] ?? "",
      nickName: json["nickName"] ?? "",
      avatar: json["avatar"] ?? "",
      signature: json["signature"] ?? "",
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