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
import '../../utils/WebSocketManager.dart';
import '../../utils/presence_event.dart';
import '../../utils/friend_sort_util.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Friendspage extends StatefulWidget {
  final List<Friend> friendListDate;
  final bool autoRefresh;

  const Friendspage({
    super.key,
    required this.friendListDate,
    this.autoRefresh = true,
  });

  @override
  _FriendsPage createState() => _FriendsPage();
}

class _FriendsPage extends State<Friendspage>
    with AutomaticKeepAliveClientMixin {
  List<Friend> friends = [];
  Map<String, String> previousAvatars = {};
  Timer? _pollingTimer;
  WebSocketMessageSubscription? _presenceSubscription;
  WebSocketStatusSubscription? _webSocketStatusSubscription;
  final Map<String, bool> _presenceOverrides = {};
  final GlobalUtil _globalUtil = GlobalUtil();
  int _friendRequestCount = 0;
  List<FriendRequestModel> _pendingRequests = [];
  Set<int> _seenIncomingRequestIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _friendScrollController = ScrollController();
  String _searchQuery = '';
  bool _isRefreshing = false;

  static const _alphabetIndex = <String>[
    '↑',
    '#',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    friends = List<Friend>.from(widget.friendListDate);
    if (!widget.autoRefresh) return;
    final webSocketManager = WebSocketManager();
    _presenceSubscription = webSocketManager.addMessageListener(
      _handlePresenceMessage,
    );
    _webSocketStatusSubscription = webSocketManager.addStatusListener((status) {
      if (status == WebSocketStatus.connected && mounted) {
        _presenceOverrides.clear();
        _refreshFriends();
      }
    });
    unawaited(_initializeRequestNotices());
  }

  Future<void> _initializeRequestNotices() async {
    final userName = _globalUtil.userName?.trim() ?? '';
    if (userName.isNotEmpty) {
      final preferences = await SharedPreferences.getInstance();
      _seenIncomingRequestIds =
          preferences
              .getStringList('seen_friend_request_ids_$userName')
              ?.map(int.tryParse)
              .whereType<int>()
              .toSet() ??
          <int>{};
    }
    if (mounted) _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _presenceSubscription?.cancel();
    _webSocketStatusSubscription?.cancel();
    _searchController.dispose();
    _friendScrollController.dispose();
    super.dispose();
  }

  void _handlePresenceMessage(dynamic message) {
    if (message is Map<String, dynamic> &&
        message['type'] == 'friendRequestUpdated') {
      final action = message['action']?.toString();
      final target = message['toUserId']?.toString();
      if (action == 'created' && target == _globalUtil.userName) {
        final requestId = int.tryParse(message['id']?.toString() ?? '');
        if (requestId != null) _seenIncomingRequestIds.remove(requestId);
      }
      unawaited(_refreshFriends());
      return;
    }
    final event = PresenceEvent.tryParse(message);
    if (event == null || !mounted) return;

    _presenceOverrides[event.userName] = event.isOnline;
    final globalFriend = _globalUtil.userInfoModel.friendListData
        ?.where((friend) => friend.userName == event.userName)
        .firstOrNull;
    if (globalFriend != null) globalFriend.isOnline = event.isOnline;

    final index = friends.indexWhere(
      (friend) => friend.userName == event.userName,
    );
    if (index == -1 || friends[index].isOnline == event.isOnline) return;
    setState(() {
      friends[index] = friends[index].copyWith(isOnline: event.isOnline);
    });
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
          _pendingRequests = requests;
          _friendRequestCount = requests.where((request) {
            final id = request.requestId;
            return request.isIncoming &&
                request.status == RequestStatus.pending &&
                id != null &&
                !_seenIncomingRequestIds.contains(id);
          }).length;
        });
      }
    } catch (e) {
      debugPrint('获取好友申请列表失败: $e');
    }
  }

  Future<void> _markIncomingRequestsSeen() async {
    final ids = _pendingRequests
        .where(
          (request) =>
              request.isIncoming && request.status == RequestStatus.pending,
        )
        .map((request) => request.requestId)
        .whereType<int>();
    _seenIncomingRequestIds.addAll(ids);
    if (mounted) setState(() => _friendRequestCount = 0);
    final userName = _globalUtil.userName?.trim() ?? '';
    if (userName.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'seen_friend_request_ids_$userName',
      _seenIncomingRequestIds.map((id) => id.toString()).toList(),
    );
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
          final newFriends = userInfo.friendListData!.map((f) {
            final avatarName = f.avatar ?? '';
            final userName = f.userName ?? '';
            final remark = f.remarks?.trim() ?? '';
            // 使用 globalUtil.getImageURL 生成头像 URL
            String avatarURL = _globalUtil.getImageURL(userName, avatarName);
            final previousAvatar = previousAvatars[userName] ?? '';
            // 只有当 URL 不同时才更新缓存
            if (avatarURL != previousAvatar && avatarURL.isNotEmpty) {
              previousAvatars[userName] = avatarURL;
            }
            final isOnline =
                _presenceOverrides[userName] ?? f.isOnline ?? false;
            f.isOnline = isOnline;
            return Friend(
              userName: userName,
              remark: remark,
              name: remark.isNotEmpty ? remark : f.nickName ?? '',
              avatar: avatarName.isNotEmpty ? avatarURL : '👤',
              nickName: f.nickName ?? '',
              previousAvatar: previousAvatars[userName] ?? '',
              signature: f.signature ?? '',
              time: '',
              isOnline: isOnline,
            );
          }).toList();
          _globalUtil.userInfoModel = userInfo;
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
    final result = keyword.isEmpty
        ? List<Friend>.from(friends)
        : friends
              .where(
                (friend) => FriendSearchUtil.matches(
                  keyword: keyword,
                  displayName: friend.name,
                  nickname: friend.nickName,
                ),
              )
              .toList();
    result.sort(
      (left, right) => FriendSortUtil.compare(
        leftOnline: left.isOnline,
        leftDisplayName: left.name,
        leftUserName: left.userName,
        rightOnline: right.isOnline,
        rightDisplayName: right.name,
        rightUserName: right.userName,
      ),
    );
    return result;
  }

  Future<void> _openFriendDetail(Friend friend) async {
    final friendDeleted = await Navigator.pushNamed(
      context,
      '/friendDetailPage',
      arguments: {
        'avatar': friend.avatar,
        'remark': friend.remark,
        'nickname': friend.nickName,
        'userName': friend.userName,
        'signature': friend.signature,
        'isFriend': true,
      },
    );
    if (!mounted) return;

    if (friendDeleted == true) {
      setState(() {
        friends = friends
            .where((item) => item.userName != friend.userName)
            .toList();
      });
      await _fetchFriendList();
      return;
    }

    final cachedFriend = _globalUtil.userInfoModel.friendListData
        ?.where((item) => item.userName == friend.userName)
        .firstOrNull;
    if (cachedFriend != null) {
      final latestRemark = cachedFriend.remarks?.trim() ?? '';
      setState(() {
        friends = friends.map((item) {
          if (item.userName != friend.userName) return item;
          return item.copyWith(
            remark: latestRemark,
            name: latestRemark.isNotEmpty ? latestRemark : item.nickName,
          );
        }).toList();
      });
    }
    await _fetchFriendList();
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
    return Material(
      color: context.appSurface,
      child: InkWell(
        onTap: () => _openFriendDetail(friend),
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 30),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      backgroundColor: context.appSearchBackground,
                      radius: 23,
                      child: ClipOval(
                        child: friend.avatar != '👤'
                            ? CachedNetworkImage(
                                cacheManager: AppImageCache.manager,
                                imageUrl: friend.avatar,
                                cacheKey: AppImageCache.cacheKey(friend.avatar),
                                fit: BoxFit.cover,
                                width: 46,
                                height: 46,
                                errorWidget: (context, url, error) => Icon(
                                  Icons.person_rounded,
                                  color: context.appTextSecondary,
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                color: context.appTextSecondary,
                              ),
                      ),
                    ),
                    if (friend.isOnline)
                      Positioned(
                        bottom: 0,
                        right: -1,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.appSurface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isSearching
                          ? _buildHighlightedText(
                              friend.name,
                              normalStyle: TextStyle(
                                color: context.appTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : Text(
                              friend.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      const SizedBox(height: 5),
                      if (isSearching && hasDistinctNickname)
                        Row(
                          children: [
                            Text(
                              '昵称：',
                              style: TextStyle(
                                color: context.appTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Expanded(
                              child: _buildHighlightedText(
                                friend.nickName,
                                normalStyle: TextStyle(
                                  color: context.appTextSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          friend.signature.trim().isEmpty
                              ? '这个人很安静，暂时没有个性签名'
                              : friend.signature,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          height: 92,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: AppColors.primary, size: 29),
                  if (badge > 0)
                    Positioned(
                      top: -9,
                      right: -14,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 22),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutCard() {
    return Container(
      key: const ValueKey('friends_shortcut_card'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildShortcutAction(
            icon: Icons.person_add_alt_1_rounded,
            label: '新的朋友',
            badge: _friendRequestCount,
            onTap: () async {
              final navigator = Navigator.of(context);
              await _markIncomingRequestsSeen();
              if (!mounted) return;
              navigator
                  .pushNamed(
                    '/friendAddManagerPage',
                    arguments: _pendingRequests,
                  )
                  .then((_) {
                    if (!mounted) return;
                    unawaited(_refreshFriends());
                  });
            },
          ),
          SizedBox(
            height: 46,
            child: VerticalDivider(width: 1, color: context.appDivider),
          ),
          _buildShortcutAction(
            icon: Icons.person_add_rounded,
            label: '添加好友',
            onTap: _showFindFriend,
          ),
          SizedBox(
            height: 46,
            child: VerticalDivider(width: 1, color: context.appDivider),
          ),
          _buildShortcutAction(
            icon: Icons.groups_rounded,
            label: '我的群聊',
            onTap: () => Navigator.pushNamed(context, '/groupChatListPage'),
          ),
        ],
      ),
    );
  }

  void _jumpToInitial(String initial) {
    if (!_friendScrollController.hasClients) return;
    if (initial == '↑') {
      _friendScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
      return;
    }

    final index = _filteredFriends.indexWhere((friend) {
      return FriendSortUtil.initial(
            displayName: friend.name,
            userName: friend.userName,
          ) ==
          initial;
    });
    if (index < 0) return;
    _friendScrollController.animateTo(
      (index * 73)
          .toDouble()
          .clamp(0, _friendScrollController.position.maxScrollExtent)
          .toDouble(),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Widget _buildAlphabetIndex() {
    return Positioned(
      key: const ValueKey('friends_alphabet_index'),
      top: 8,
      right: 2,
      bottom: 8,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _alphabetIndex.map((letter) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _jumpToInitial(letter),
            child: SizedBox(
              width: 25,
              child: Text(
                letter,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF73777D),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState({required bool searching}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                searching ? Icons.person_search_rounded : Icons.people_outline,
                size: 48,
                color: const Color(0xFFD3D5D9),
              ),
              const SizedBox(height: 12),
              Text(
                searching ? '没有找到匹配的好友' : '暂时还没有好友',
                style: TextStyle(color: context.appTextSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFriendList() {
    final searching = _searchQuery.trim().isNotEmpty;
    if (_filteredFriends.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshFriends,
        child: _buildEmptyState(searching: searching),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshFriends,
          child: ListView.separated(
            controller: _friendScrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(right: searching ? 0 : 18),
            itemCount: _filteredFriends.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 0.6,
              indent: 76,
              endIndent: 16,
              color: context.appDivider,
            ),
            itemBuilder: (context, index) => _buildFriendTile(
              _filteredFriends[index],
              isSearching: searching,
            ),
          ),
        ),
        if (!searching) _buildAlphabetIndex(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final searching = _searchQuery.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        centerTitle: true,
        title: Text(
          '好友',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PopupMenuButton<String>(
              tooltip: '更多操作',
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF34373C)),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: context.appTextPrimary,
                  size: 22,
                ),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem<String>(value: 'findGroup', child: Text('创建群聊')),
              ],
              onSelected: (value) {
                if (value == 'findGroup') _showFindGroup();
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: context.appSurface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: AppSearchField(
              controller: _searchController,
              query: _searchQuery,
              hintText: '搜索好友昵称或备注',
              onChanged: (value) => setState(() => _searchQuery = value),
              height: 44,
            ),
          ),
          if (!searching) _buildShortcutCard(),
          Expanded(
            child: Container(
              key: const ValueKey('friends_list_surface'),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
                    child: Row(
                      children: [
                        Text(
                          '好友',
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_filteredFriends.length}',
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        if (!searching)
                          Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 7,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 5),
                              Text(
                                '在线优先',
                                style: TextStyle(
                                  color: context.appTextSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: context.appDivider),
                  Expanded(child: _buildFriendList()),
                ],
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
  final String remark;
  final String name;
  final String nickName;
  final String avatar;
  final String previousAvatar;
  final String signature;
  final String time;
  final bool isOnline;

  Friend({
    required this.userName,
    required this.remark,
    required this.name,
    required this.nickName,
    required this.avatar,
    required this.previousAvatar,
    required this.signature,
    required this.time,
    required this.isOnline,
  });

  Friend copyWith({bool? isOnline, String? remark, String? name}) {
    return Friend(
      userName: userName,
      remark: remark ?? this.remark,
      name: name ?? this.name,
      nickName: nickName,
      avatar: avatar,
      previousAvatar: previousAvatar,
      signature: signature,
      time: time,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}
