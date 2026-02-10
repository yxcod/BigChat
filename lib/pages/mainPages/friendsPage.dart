import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/gloabl.dart';
import '../../api/getInfoAPI.dart';
import '../../api/getFriendRequestsAPI.dart';
import '../../model/friendRequestModel.dart';

class Friendspage extends StatefulWidget {
  final List<Friend> friendListDate;
  Friendspage({Key? key, required this.friendListDate}) : super(key: key);
  @override
  _FriendsPage createState() => _FriendsPage();
}

class _FriendsPage extends State<Friendspage>
    with AutomaticKeepAliveClientMixin {
  List<Friend> friends = [];
  Map<String, String> previousAvatars = {};
  Timer? _pollingTimer;
  final GlobalUtil _globalUtil = GlobalUtil();
  int _friendRequestCount = 0;
  List<FriendRequestModel> _pendingRequests = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _fetchFriendList();
      _fetchFriendRequests();
    });
    _fetchFriendList();
    _fetchFriendRequests();
  }

  Future<void> _fetchFriendRequests() async {
    // 获取好友申请列表
    final userName = _globalUtil.userName;
    if (userName == null || userName.isEmpty) {
      return;
    }
    try {
      final requests = await getFriendRequestsApi(userName);
      if (mounted) {
        setState(() {
          // 将新获取的申请添加到现有列表中，避免覆盖未处理的申请
          if (requests.isNotEmpty) {
            // 获取现有申请的ID集合
            final existingIds = _pendingRequests
                .map((r) => r.requestId)
                .toSet();

            // 添加新的、不重复的申请
            for (var request in requests) {
              if (!existingIds.contains(request.requestId)) {
                _pendingRequests.add(request);
              }
            }
          }

          // 红点显示的数量按照最新的网络响应，用于提示未读的申请
          _friendRequestCount = requests.length;
        });
      }
    } catch (e) {
      debugPrint('获取好友申请列表失败: $e');
    }
  }

  Future<void> _fetchFriendList() async {
    final userName = _globalUtil.userName;
    if (userName == null || userName.isEmpty) {
      return;
    }
    try {
      final userInfo = await getUserInfoApi(userName);
      if (mounted) {
        if (userInfo.friendListData != null) {
          _globalUtil.userInfoModel = userInfo;
          final newFriends = userInfo.friendListData!.map((f) {
            final avatarName = f.avatar ?? '';
            final userName = f.userName ?? '';
            // 使用 globalUtil.getImageURL 生成头像 URL
            String avatarURL = _globalUtil.getImageURL(userName, avatarName);
            final previousAvatar = previousAvatars[userName] ?? '';
            // 只有当 URL 不同时才更新缓存
            if (avatarURL != previousAvatar && avatarURL.isNotEmpty) {
              previousAvatars[userName] = avatarURL;
            }
            return Friend(
              userName: userName,
              name: f.remarks?.isNotEmpty == true
                  ? f.remarks!
                  : f.nickName ?? '',
              avatar: avatarName.isNotEmpty ? avatarURL : '👤',
              nickName: f.nickName ?? '',
              previousAvatar: previousAvatars[userName] ?? '',
              signature: f.signature ?? '',
              time: '',
              isOnline: f.isOnline ?? false,
            );
          }).toList();
          setState(() {
            friends = newFriends;
          });
        }
      }
    } catch (e) {
      debugPrint('获取好友列表失败: $e');
    }
  }

  //搜索好友
  void _showFindFriend() {
    Navigator.pushNamed(context, '/searchFriendPage');
  }

  //新建群聊
  void _showFindGroup() {
    Navigator.pushNamed(context, '/groupCreatePage');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: 60,
        title: Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            //key: _popupButtonKey,
            icon: Icon(Icons.add, color: Colors.black),
            offset: Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(value: 'findFriend', child: Text('添加好友')),
              PopupMenuItem<String>(value: 'findGroup', child: Text('添加群聊')),
            ],
            onSelected: (String value) {
              if (value == 'findFriend') {
                _showFindFriend();
              } else if (value == 'findGroup') {
                _showFindGroup();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部按钮
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person_add, color: Colors.green),
                  title: Text('新的朋友'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_friendRequestCount > 0)
                        Container(
                          margin: EdgeInsets.only(right: 8),
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_friendRequestCount',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey,
                        size: 16,
                      ),
                    ],
                  ),
                  onTap: () {
                    // 进入好友验证页面
                    Navigator.pushNamed(
                      context,
                      '/friendAddManagerPage',
                      arguments: _pendingRequests,
                    ).then((_) {
                      // 返回后只清除红点提示，不清除好友申请数据
                      setState(() {
                        _friendRequestCount = 0;
                      });
                    });
                  },
                ),
                Divider(height: 1, color: Colors.grey[200]),
                ListTile(
                  leading: Icon(Icons.group, color: Colors.green),
                  title: Text('我的群聊'),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onTap: () {
                    Navigator.pushNamed(context, '/groupChatListPage');
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 10),

          // 好友列表
          Expanded(
            child: ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                Widget item = ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        radius: 20,
                        child: ClipOval(
                          child: friends[index].avatar != '👤'
                              ? Image.network(
                                  friends[index].avatar,
                                  fit: BoxFit.cover,
                                  width: 40,
                                  height: 40,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                    );
                                  },
                                )
                              : Icon(Icons.person, color: Colors.grey),
                        ),
                      ),
                      // 在线状态指示器 - 放置在CircleAvatar外部，避免被裁剪
                      if (friends[index].isOnline) ...[
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  title: Text(
                    friends[index].name,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    friends[index].signature,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    Map<String, dynamic> friendData = {
                      'avatar': friends[index].avatar,
                      'remark': friends[index].name,
                      'nickname': friends[index].nickName,
                      'userName': friends[index].userName,
                    };
                    Navigator.pushNamed(
                      context,
                      '/friendDetailPage',
                      arguments: friendData,
                    );
                  },
                );

                if (index < friends.length - 1) {
                  return Column(
                    children: [
                      item,
                      Divider(height: 1, color: Colors.grey[300], indent: 70),
                    ],
                  );
                }
                return item;
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 好友数据模型
class Friend {
  final String userName;
  final String name;
  final String nickName;
  final String avatar;
  final String previousAvatar;
  final String signature;
  final String time;
  final bool isOnline;

  Friend({
    required this.userName,
    required this.name,
    required this.nickName,
    required this.avatar,
    required this.previousAvatar,
    required this.signature,
    required this.time,
    required this.isOnline,
  });
}
