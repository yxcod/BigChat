import 'package:flutter/material.dart';
import '../../model/friendRequestModel.dart';
import '../../utils/Gloabl.dart';
import '../../api/getFriendRequestsAPI.dart';
import '../../core/cache/app_image_cache.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../app/theme/app_colors.dart';

class FriendAddManagerPage extends StatefulWidget {
  final List<FriendRequestModel>? initialRequests;
  final List<RecentFriendModel>? initialRecentFriends;
  final bool autoLoad;

  const FriendAddManagerPage({
    super.key,
    this.initialRequests,
    this.initialRecentFriends,
    this.autoLoad = true,
  });

  @override
  _FriendAddManagerPageState createState() => _FriendAddManagerPageState();
}

class _FriendAddManagerPageState extends State<FriendAddManagerPage> {
  // 验证申请数据
  List<FriendRequestModel> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _recentFriends = List<RecentFriendModel>.from(
      widget.initialRecentFriends ?? const [],
    );
    if (widget.initialRequests != null && widget.initialRequests!.isNotEmpty) {
      _pendingRequests = List<FriendRequestModel>.from(widget.initialRequests!);

      if (widget.autoLoad) _sendAllRequestsSeen();
    }
    if (widget.autoLoad) _loadRecentFriends();
  }

  // 加载最近好友列表
  void _loadRecentFriends() {
    final currentUserName = GlobalUtil().userName;
    if (currentUserName == null || currentUserName.isEmpty) {
      debugPrint('获取当前用户信息失败');
      return;
    }

    // 调用API获取最近好友列表
    getRecentFriendsApi(currentUserName)
        .then((friends) {
          if (!mounted) return;
          setState(() {
            _recentFriends = friends;
          });
          debugPrint('成功获取最近好友列表，共${friends.length}位好友');
        })
        .catchError((error) {
          debugPrint('获取最近好友列表失败: $error');
        });
  }

  // 当进入页面时，为所有好友申请发送已查看的请求(requestResult=4)
  void _sendAllRequestsSeen() {
    for (var request in _pendingRequests) {
      if (request.requestId != null) {
        _sendHandleRequest(request.requestId!, 4);
      }
    }
  }

  // 封装发送请求的方法
  void _sendHandleRequest(int requestId, int requestResult) {
    handleFriendRequestApi(requestId, requestResult)
        .then((response) {
          debugPrint('发送处理请求成功: $response');
        })
        .catchError((error) {
          debugPrint('发送处理请求失败: $error');
        });
  }

  // 最近添加的好友数据
  List<RecentFriendModel> _recentFriends = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text(
          '新的朋友',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const AppBackButton(),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          _buildVerificationSection(),
          const SizedBox(height: 24),
          _buildRecentFriendsSection(),
        ],
      ),
    );
  }

  Widget _buildVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: '待处理',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: '  ${_pendingRequests.length}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        Container(
          key: const ValueKey('friend_request_card'),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 14,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: _pendingRequests.isEmpty
              ? const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      '暂无待处理的好友申请',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(_pendingRequests.length, (index) {
                    return Column(
                      children: [
                        _buildRequestItem(_pendingRequests[index]),
                        if (index < _pendingRequests.length - 1)
                          const Divider(
                            height: 1,
                            indent: 78,
                            endIndent: 14,
                            color: AppColors.divider,
                          ),
                      ],
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _buildRecentFriendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近添加',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 11),
        Container(
          key: const ValueKey('recent_friends_card'),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 14,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: _recentFriends.isEmpty
              ? const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      '最近没有添加新好友',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(_recentFriends.length, (index) {
                    return Column(
                      children: [
                        _buildFriendItem(_recentFriends[index]),
                        if (index < _recentFriends.length - 1)
                          const Divider(
                            height: 1,
                            indent: 76,
                            endIndent: 14,
                            color: AppColors.divider,
                          ),
                      ],
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _buildRequestItem(FriendRequestModel request) {
    // 获取头像URL
    String getAvatarUrl() {
      try {
        return GlobalUtil().getImageURL(request.userName ?? '', "head.jpg");
      } catch (_) {
        // 如果获取失败，返回一个默认的表情
        return request.userName?.substring(0, 1) ?? '';
      }
    }

    final avatarUrl = getAvatarUrl();
    final isNetworkImage = avatarUrl.startsWith('http');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFFF0F1F3),
            backgroundImage: isNetworkImage
                ? AppImageCache.provider(avatarUrl)
                : null,
            child: isNetworkImage
                ? null
                : Text(
                    isNetworkImage ? '' : avatarUrl,
                    style: const TextStyle(
                      fontSize: 20,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.nickName ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  request.verificationMessage?.trim().isNotEmpty == true
                      ? request.verificationMessage!
                      : '申请添加你为好友',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(request.requestTime ?? DateTime.now()),
                  style: const TextStyle(
                    color: Color(0xFFA0A3A8),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: Column(
              children: [
                SizedBox(
                  width: 68,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: () => _handleAccept(request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '同意',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 68,
                  height: 34,
                  child: OutlinedButton(
                    onPressed: () => _handleReject(request),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: Color(0xFFD4D6DA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('忽略', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(RecentFriendModel friend) {
    // 获取头像URL
    String getAvatarUrl() {
      try {
        return GlobalUtil().getImageURL(friend.userName ?? '', "head.jpg");
      } catch (_) {
        // 如果获取失败，返回用户名的第一个字符
        return friend.userName?.substring(0, 1) ?? '';
      }
    }

    final avatarUrl = getAvatarUrl();
    final isNetworkImage = avatarUrl.startsWith('http');

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => _showFriendDetail(friend),
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFF0F1F3),
                  backgroundImage: isNetworkImage
                      ? AppImageCache.provider(avatarUrl)
                      : null,
                  child: isNetworkImage
                      ? null
                      : Text(
                          avatarUrl,
                          style: const TextStyle(
                            fontSize: 19,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.nickName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '已添加 · ${_formatTime(friend.addTime != null ? DateTime.fromMillisecondsSinceEpoch(friend.addTime!) : DateTime.now())}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB1B3B7),
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleAccept(FriendRequestModel request) {
    setState(() {
      request.status = RequestStatus.accepted;
      _pendingRequests.remove(request);

      // 添加到最近好友列表
      _recentFriends.insert(
        0,
        RecentFriendModel(
          userName: request.userName ?? '',
          nickName: request.nickName ?? '',
          addTime: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    });

    // 发送同意请求
    if (request.requestId != null) {
      _sendHandleRequest(request.requestId!, 1);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已同意 ${request.nickName} 的好友申请'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _handleReject(FriendRequestModel request) {
    setState(() {
      request.status = RequestStatus.rejected;
      _pendingRequests.remove(request);
    });

    // 发送拒绝请求
    if (request.requestId != null) {
      _sendHandleRequest(request.requestId!, 2);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已拒绝 ${request.nickName} 的好友申请'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showFriendDetail(RecentFriendModel friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(friend.nickName ?? ''),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用户: ${friend.userName ?? ""}'),
            Text('备注: ${friend.remarks ?? "无"}'),
            Text(
              '添加时间: ${_formatTime(friend.addTime != null ? DateTime.fromMillisecondsSinceEpoch(friend.addTime!) : DateTime.now())}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('关闭'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    }
  }
}
