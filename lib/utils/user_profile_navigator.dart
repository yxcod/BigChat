import 'package:flutter/material.dart';

import '../api/getInfoAPI.dart';
import '../model/friendInfoModel.dart';
import 'gloabl.dart';

Future<void> openUserProfile(
  BuildContext context, {
  required String userName,
  String? fallbackNickname,
  String? fallbackAvatarName,
}) async {
  final normalizedUserName = userName.trim();
  if (normalizedUserName.isEmpty) {
    return;
  }

  final globalUtil = GlobalUtil();
  FriendInfoModel? friendInfo;
  for (final friend
      in globalUtil.userInfoModel.friendListData ?? const <FriendInfoModel>[]) {
    if (friend.userName == normalizedUserName) {
      friendInfo = friend;
      break;
    }
  }

  var nickname = friendInfo?.nickName ?? fallbackNickname ?? normalizedUserName;
  var avatarName = friendInfo?.avatar ?? fallbackAvatarName ?? '';
  var signature = friendInfo?.signature ?? '';

  try {
    final userInfo = await getUserInfoApi(normalizedUserName);
    if ((userInfo.nickName ?? '').trim().isNotEmpty) {
      nickname = userInfo.nickName!.trim();
    }
    if ((userInfo.avatar ?? '').trim().isNotEmpty) {
      avatarName = userInfo.avatar!.trim();
    }
    if ((userInfo.signature ?? '').trim().isNotEmpty) {
      signature = userInfo.signature!.trim();
    }
  } catch (error) {
    debugPrint('加载用户基础资料失败，使用聊天中的缓存信息: $error');
  }

  var avatarUrl = avatarName;
  if (avatarName.isNotEmpty &&
      !avatarName.startsWith('http://') &&
      !avatarName.startsWith('https://')) {
    try {
      avatarUrl = globalUtil.getImageURL(normalizedUserName, avatarName);
    } catch (error) {
      debugPrint('生成用户头像地址失败: $error');
      avatarUrl = '';
    }
  }

  if (!context.mounted) {
    return;
  }

  Navigator.pushNamed(
    context,
    '/friendDetailPage',
    arguments: {
      'avatar': avatarUrl,
      'remark': friendInfo?.remarks ?? '',
      'nickname': nickname,
      'userName': normalizedUserName,
      'signature': signature,
      'isFriend': friendInfo != null,
    },
  );
}
