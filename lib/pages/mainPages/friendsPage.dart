import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/gloabl.dart';
import '../../api/getInfoAPI.dart';
import '../../api/getFriendRequestsAPI.dart';
import '../../model/friendRequestModel.dart';
import '../../utils/friend_search_util.dart';
import '../../shared/widgets/app_search_field.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/cache/app_image_cache.dart';
import '../../core/config/refresh_intervals.dart';

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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRefreshing = false;

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
    _searchController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(
      RefreshIntervals.friendFallback,
      (timer) => _refreshFriends(),
    );
    _refreshFriends();
  }

  Future<void> _refreshFriends() async {
    if (_isRefreshing) {
      return;
    }
    _isRefreshing = true;
    try {
      await Future.wait([_fetchFriendList(), _fetchFriendRequests()]);
    } finally {
      _isRefreshing = false;
    }
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

  List<Friend> get _filteredFriends {
    final keyword = _searchQuery.trim();
    if (keyword.isEmpty) {
      return friends;
    }
    return friends
        .where(
          (friend) => FriendSearchUtil.matches(
            keyword: keyword,
            displayName: friend.name,
            nickname: friend.nickName,
          ),
        )
        .toList();
  }

  void _openFriendDetail(Friend friend) {
    Navigator.pushNamed(
      context,
      '/friendDetailPage',
      arguments: {
        'avatar': friend.avatar,
        'remark': friend.name,
        'nickname': friend.nickName,
        'userName': friend.userName,
        'signature': friend.signature,
        'isFriend': true,
      },
    );
  }

  Widget _buildHighlightedText(String text, {required TextStyle normalStyle}) {
    return Text.rich(
      TextSpan(
        children: FriendSearchUtil.buildHighlightedSpans(
          text: text,
          keyword: _searchQuery,
          normalStyle: normalStyle,
          highlightedStyle: normalStyle.copyWith(
            color: const Color(0xFF07C160),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFriendTile(Friend friend, {required bool isSearching}) {
    final hasDistinctNickname =
        friend.nickName.isNotEmpty &&
        friend.nickName.trim() != friend.name.trim();
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[200],
            radius: 20,
            child: ClipOval(
              child: friend.avatar != '👤'
                  ? CachedNetworkImage(
                      cacheManager: AppImageCache.manager,
                      imageUrl: friend.avatar,
                      cacheKey: AppImageCache.cacheKey(friend.avatar),
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                      errorWidget: (context, url, error) {
                        return Icon(Icons.person, color: Colors.grey);
                      },
                    )
                  : Icon(Icons.person, color: Colors.grey),
            ),
          ),
          if (friend.isOnline)
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
      ),
      title: isSearching
          ? _buildHighlightedText(
              friend.name,
              normalStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            )
          : Text(
              friend.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
      subtitle: isSearching && hasDistinctNickname
          ? Row(
              children: [
                Text(
                  '昵称：',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                Expanded(
                  child: _buildHighlightedText(
                    friend.nickName,
                    normalStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            )
          : Text(
              friend.signature,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
      onTap: () => _openFriendDetail(friend),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: 64,
        titleSpacing: 12,
        title: AppSearchField(
          controller: _searchController,
          query: _searchQuery,
          hintText: '搜索好友昵称或备注',
          onChanged: (value) => setState(() => _searchQuery = value),
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
          if (_searchQuery.trim().isEmpty)
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
          if (_searchQuery.trim().isEmpty) SizedBox(height: 10),

          // 好友列表
          Expanded(
            child: _filteredFriends.isEmpty && _searchQuery.trim().isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_search,
                          size: 52,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '没有找到匹配的好友',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refreshFriends,
                    child: ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount:
                          _filteredFriends.length +
                          (_searchQuery.trim().isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_searchQuery.trim().isNotEmpty && index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                            child: Text(
                              '好友（${_filteredFriends.length}）',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          );
                        }
                        final friendIndex =
                            index - (_searchQuery.trim().isNotEmpty ? 1 : 0);
                        final friend = _filteredFriends[friendIndex];
                        final item = _buildFriendTile(
                          friend,
                          isSearching: _searchQuery.trim().isNotEmpty,
                        );

                        if (friendIndex < _filteredFriends.length - 1) {
                          return Column(
                            children: [
                              item,
                              Divider(
                                height: 1,
                                color: Colors.grey[300],
                                indent: 70,
                              ),
                            ],
                          );
                        }
                        return item;
                      },
                    ),
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
