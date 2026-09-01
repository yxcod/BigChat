import 'package:flutter_base/features/account/data/user_info_cache.dart';
import 'package:flutter_base/model/friendInfoModel.dart';
import 'package:flutter_base/model/userInfoModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restores the profile and friend list for the same account', () async {
    final storage = <String, String>{};
    final cache = UserInfoCache(
      readString: (key) => storage[key],
      writeString: (key, value) async => storage[key] = value,
    );
    final profile = UserInfoModel(
      userName: 'owner',
      nickName: '本地昵称',
      avatar: 'avatar.jpg',
      signature: '本地签名',
      friendListData: [
        FriendInfoModel(
          userName: 'friend',
          nickName: '好友',
          remarks: '备注',
          avatar: '',
          signature: '签名',
          isOnline: false,
        ),
      ],
    );

    await cache.save('owner', profile);

    final restored = cache.load('owner');
    expect(restored?.nickName, '本地昵称');
    expect(restored?.friendListData?.single.remarks, '备注');
    expect(cache.load('other'), isNull);
  });

  test('never restores a snapshot under a mismatched account', () async {
    final storage = <String, String>{};
    final cache = UserInfoCache(
      readString: (key) => storage[key],
      writeString: (key, value) async => storage[key] = value,
    );
    final profile = UserInfoModel(
      userName: 'alice',
      nickName: 'Alice',
      avatar: '',
      signature: '',
      friendListData: const [],
    );

    await cache.save('bob', profile);

    expect(cache.load('bob'), isNull);
    expect(storage, isEmpty);
  });
}
