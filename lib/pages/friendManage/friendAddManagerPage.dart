import 'package:flutter/material.dart';
import '../../model/friendRequestModel.dart';
import '../../model/messageModel.dart';
import '../../utils/Gloabl.dart';
import '../../api/getFriendRequestsAPI.dart';
import '../../core/cache/app_image_cache.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';
import '../../utils/WebSocketManager.dart';

typedef ExpiredFriendRequestDelete =
    Future<bool> Function(FriendRequestModel request);

class FriendAddManagerPage extends StatefulWidget {
  final List<FriendRequestModel>? initialRequests;
  final List<RecentFriendModel>? initialRecentFriends;
  final bool autoLoad;
  final ExpiredFriendRequestDelete? deleteExpiredRequest;

  const FriendAddManagerPage({
    super.key,
    this.initialRequests,
    this.initialRecentFriends,
    this.autoLoad = true,
    this.deleteExpiredRequest,
  });

  @override
  _FriendAddManagerPageState createState() => _FriendAddManagerPageState();
}

class _FriendAddManagerPageState extends State<FriendAddManagerPage> {
  // 验证申请数据
  List<FriendRequestModel> _pendingRequests = [];
  WebSocketMessageSubscription? _friendRequestSubscription;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _recentFriends = List<RecentFriendModel>.from(
      widget.initialRecentFriends ?? const [],
    );
    if (widget.initialRequests != null && widget.initialRequests!.isNotEmpty) {
      _pendingRequests = List<FriendRequestModel>.from(widget.initialRequests!);
    }
    if (widget.autoLoad) {
      _friendRequestSubscription = WebSocketManager().addMessageListener(
        _handleRealtimeEvent,
      );
      _reload();
    }
  }

  @override
  void dispose() {
    _friendRequestSubscription?.cancel();
    super.dispose();
  }

  void _handleRealtimeEvent(dynamic event) {
    if (event is Map<String, dynamic> &&
        event['type'] == 'friendRequestUpdated') {
      _reload();
    }
  }

  Future<void> _reload() async {
    if (_isLoading) return;
    final currentUserName = GlobalUtil().userName?.trim() ?? '';
    if (currentUserName.isEmpty) return;
    _isLoading = true;
    try {
      final results = await Future.wait<dynamic>([
        getFriendRequestsApi(currentUserName),
        getRecentFriendsApi(currentUserName),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingRequests = results[0] as List<FriendRequestModel>;
        _recentFriends = results[1] as List<RecentFriendModel>;
      });
    } catch (error) {
      debugPrint('刷新好友申请失败: $error');
    } finally {
      _isLoading = false;
    }
  }

  // 最近添加的好友数据
  List<RecentFriendModel> _recentFriends = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        title: Text(
          '新的朋友',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.appSurface,
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
              TextSpan(
                text: '待处理',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: '  ${_pendingRequests.length}',
                style: TextStyle(color: context.appTextSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        Container(
          key: const ValueKey('friend_request_card'),
          decoration: BoxDecoration(
            color: context.appSurface,
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
              ? SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      '暂无待处理的好友申请',
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: List.generate(_pendingRequests.length, (index) {
                    final request = _pendingRequests[index];
                    return Column(
                      children: [
                        request.status == RequestStatus.expired
                            ? Dismissible(
                                key: ValueKey(
                                  'expired_friend_request_${request.requestId ?? index}',
                                ),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (_) =>
                                    _deleteExpiredRequest(request),
                                onDismissed: (_) {
                                  setState(() {
                                    _pendingRequests.removeWhere(
                                      (item) => identical(item, request),
                                    );
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('已删除过期申请'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                background: Container(
                                  color: const Color(0xFFE53935),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 22),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '删除',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                child: _buildRequestItem(request),
                              )
                            : _buildRequestItem(request),
                        if (index < _pendingRequests.length - 1)
                          Divider(
                            height: 1,
                            indent: 78,
                            endIndent: 14,
                            color: context.appDivider,
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
        Text(
          '最近消息',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 11),
        Container(
          key: const ValueKey('recent_friends_card'),
          decoration: BoxDecoration(
            color: context.appSurface,
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
              ? SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      '最近三天没有好友申请消息',
                      style: TextStyle(
                        color: context.appTextSecondary,
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
                          Divider(
                            height: 1,
                            indent: 76,
                            endIndent: 14,
                            color: context.appDivider,
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
            backgroundColor: context.appSearchBackground,
            backgroundImage: isNetworkImage
                ? AppImageCache.provider(avatarUrl)
                : null,
            child: isNetworkImage
                ? null
                : Text(
                    isNetworkImage ? '' : avatarUrl,
                    style: TextStyle(
                      fontSize: 20,
                      color: context.appTextSecondary,
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
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  request.verificationMessage?.trim().isNotEmpty == true
                      ? '${request.isIncoming ? '' : '我：'}${request.verificationMessage!}'
                      : request.isIncoming
                      ? '申请添加你为好友'
                      : '已发送好友申请',
                  style: TextStyle(
                    color: context.appTextSecondary,
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
          _buildRequestAction(request),
        ],
      ),
    );
  }

  Widget _buildRequestAction(FriendRequestModel request) {
    if (!request.canRespond) {
      final (label, color) = switch (request.status) {
        RequestStatus.rejected => ('已拒绝', const Color(0xFF9A6B49)),
        RequestStatus.expired => ('已过期', context.appTextSecondary),
        RequestStatus.accepted => ('已添加', AppColors.primary),
        _ => ('待验证', const Color(0xFF8A8E95)),
      };
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return SizedBox(
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                foregroundColor: context.appTextSecondary,
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Color(0xFFD4D6DA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('拒绝', style: TextStyle(fontSize: 13)),
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

    final eventTime = DateTime.fromMillisecondsSinceEpoch(
      friend.addTime ?? DateTime.now().millisecondsSinceEpoch,
    );
    final isAccepted = friend.status == RequestStatus.accepted;
    final statusText = isAccepted ? '已添加' : '已拒绝';
    final statusColor = isAccepted
        ? AppColors.primary
        : const Color(0xFF9A6B49);
    final description = switch ((friend.status, friend.direction)) {
      (RequestStatus.rejected, FriendRequestDirection.outgoing) =>
        '对方拒绝了你的好友申请',
      (RequestStatus.rejected, FriendRequestDirection.incoming) =>
        '你已拒绝对方的好友申请',
      (RequestStatus.accepted, FriendRequestDirection.outgoing) =>
        '对方已同意你的好友申请',
      _ => '你已同意对方的好友申请',
    };

    return Material(
      color: context.appSurface,
      child: InkWell(
        onTap: isAccepted ? () => _showFriendDetail(friend) : null,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 82),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: context.appSearchBackground,
                  backgroundImage: isNetworkImage
                      ? AppImageCache.provider(avatarUrl)
                      : null,
                  child: isNetworkImage
                      ? null
                      : Text(
                          avatarUrl,
                          style: TextStyle(
                            fontSize: 19,
                            color: context.appTextSecondary,
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
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$description · ${_formatTime(eventTime)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 58,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Text(
                        statusText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleAccept(FriendRequestModel request) async {
    final requestId = request.requestId;
    final userName = GlobalUtil().userName?.trim() ?? '';
    if (requestId == null || userName.isEmpty || !request.canRespond) return;
    try {
      final response = await handleFriendRequestApi(requestId, 1, userName);
      if (response['code'] != 100) throw Exception('申请已失效');
      _cacheAutomaticGreeting(response, request, userName);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已同意 ${request.nickName} 的好友申请'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('处理失败：$error')));
    }
  }

  void _cacheAutomaticGreeting(
    Map<String, dynamic> response,
    FriendRequestModel request,
    String currentUserName,
  ) {
    final rawGreeting = response['greeting'];
    if (rawGreeting is! Map) return;
    final greeting = Map<String, dynamic>.from(rawGreeting);
    final counterpart = (request.userName ?? request.fromUserId ?? '').trim();
    final msgId = int.tryParse(greeting['msgId']?.toString() ?? '');
    final timestamp =
        int.tryParse(greeting['sendTime']?.toString() ?? '') ??
        DateTime.now().millisecondsSinceEpoch;
    if (counterpart.isEmpty || msgId == null || msgId <= 0) return;
    GlobalUtil().addMessage(
      counterpart,
      Message(
        msgId: msgId,
        content: greeting['msgContent']?.toString() ?? '我们已经成功添加好友啦!',
        isMe: true,
        time: GlobalUtil.formatChatTimestamp(timestamp),
        isRead: false,
        conversationId:
            greeting['sessionId']?.toString() ??
            GlobalUtil.generateSessionId(currentUserName, counterpart),
        status: MessageStatus.sent,
        senderId: currentUserName,
        timestamp: timestamp,
      ),
    );
  }

  Future<bool> _deleteExpiredRequest(FriendRequestModel request) async {
    if (request.status != RequestStatus.expired) return false;
    final customDelete = widget.deleteExpiredRequest;
    if (customDelete != null) return customDelete(request);
    final requestId = request.requestId;
    final userName = GlobalUtil().userName?.trim() ?? '';
    if (requestId == null || userName.isEmpty) return false;
    try {
      final response = await handleFriendRequestApi(requestId, 5, userName);
      if (response['code'] == 100) return true;
      throw Exception('申请状态已发生变化');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败：$error'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _handleReject(FriendRequestModel request) async {
    final requestId = request.requestId;
    final userName = GlobalUtil().userName?.trim() ?? '';
    if (requestId == null || userName.isEmpty || !request.canRespond) return;
    try {
      final response = await handleFriendRequestApi(requestId, 2, userName);
      if (response['code'] != 100) throw Exception('申请已失效');
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已拒绝 ${request.nickName} 的好友申请'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('处理失败：$error')));
    }
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
