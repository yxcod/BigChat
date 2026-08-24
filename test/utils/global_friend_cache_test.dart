import 'package:flutter_base/model/friendInfoModel.dart';
import 'package:flutter_base/model/userInfoModel.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'updated friend remark is immediately visible from the global cache',
    () {
      final global = GlobalUtil();
      global.userInfoModel = UserInfoModel(
        userName: 'me',
        nickName: '我',
        avatar: '',
        signature: '',
        friendListData: [
          FriendInfoModel(
            userName: 'friend',
            nickName: '小李',
            remarks: '旧备注',
            avatar: '',
            signature: '',
            isOnline: true,
          ),
        ],
      );

      expect(global.updateCachedFriendRemark('friend', ' 新备注 '), isTrue);
      expect(global.getFriendInfoByUserName('friend').remarks, '新备注');

      expect(global.updateCachedFriendRemark('friend', ''), isTrue);
      expect(global.getFriendInfoByUserName('friend').remarks, isEmpty);
      expect(global.updateCachedFriendRemark('missing', '备注'), isFalse);
    },
  );
}
