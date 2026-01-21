import '../model/userInfoModel.dart';
import '../model/friendInfoModel.dart';

void main() {
  // 示例JSON数据，包含好友列表数组
  Map<String, dynamic> sampleJson = {
    "userName": "user001",
    "nickName": "张三",
    "avater": "https://example.com/avatar1.jpg",
    "signature": "这是我的签名",
    "friendListData": [
      {
        "userName": "friend001",
        "nickName": "李四",
        "remarks": "老李",
        "avater": "https://example.com/avatar2.jpg",
        "signature": "李四的签名",
      },
      {
        "userName": "friend002",
        "nickName": "王五",
        "remarks": "",
        "avater": "https://example.com/avatar3.jpg",
        "signature": "王五的签名",
      },
      {
        "userName": "friend003",
        "nickName": "赵六",
        "remarks": "小赵",
        "avater": "https://example.com/avatar4.jpg",
        "signature": "",
      },
    ],
  };

  // 解析JSON数据
  UserInfoModel userInfo = UserInfoModel.formJSON(sampleJson);

  // 打印用户信息
  print('=== 用户信息 ===');
  print('用户名: ${userInfo.userName}');
  print('昵称: ${userInfo.nickName}');
  print('头像: ${userInfo.avatar}');
  print('签名: ${userInfo.signature}');
  print('');

  // 打印好友列表
  print('=== 好友列表 (共${userInfo.friendListData?.length ?? 0}个) ===');
  if (userInfo.friendListData != null) {
    for (int i = 0; i < userInfo.friendListData!.length; i++) {
      FriendInfoModel friend = userInfo.friendListData![i];
      print('${i + 1}. 用户名: ${friend.userName}');
      print('   昵称: ${friend.nickName}');
      print('   备注: ${friend.remarks}');
      print('   头像: ${friend.avatar}');
      print('   签名: ${friend.signature}');
      print('');
    }
  }

  // 测试空数组的情况
  print('=== 测试空好友列表 ===');
  Map<String, dynamic> emptyFriendListJson = {
    "userName": "user002",
    "nickName": "测试用户",
    "avater": "https://example.com/avatar_test.jpg",
    "signature": "测试签名",
    "friendListData": [],
  };

  UserInfoModel userInfoEmpty = UserInfoModel.formJSON(emptyFriendListJson);
  print('好友数量: ${userInfoEmpty.friendListData?.length ?? 0}');
  print('');

  // 测试null的情况
  print('=== 测试null好友列表 ===');
  Map<String, dynamic> nullFriendListJson = {
    "userName": "user003",
    "nickName": "测试用户2",
    "avater": "https://example.com/avatar_test2.jpg",
    "signature": "测试签名2",
    "friendListData": null,
  };

  UserInfoModel userInfoNull = UserInfoModel.formJSON(nullFriendListJson);
  print('好友数量: ${userInfoNull.friendListData?.length ?? 0}');
}
