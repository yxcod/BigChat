import 'package:flutter/material.dart';
import '../../core/cache/app_image_cache.dart';
import '../../api/getFriendRequestsAPI.dart';
import '../../api/delete_chat_history_api.dart';
import '../../features/moments/data/moments_repository.dart';
import '../../features/moments/data/server_moments_repository.dart';
import '../../features/moments/domain/moment.dart';
import '../../features/moments/presentation/my_moments_page.dart';
import '../../utils/gloabl.dart';
import '../../utils/WebSocketManager.dart';
import '../videoCallPage.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';
import '../../core/media/video_media.dart';
import '../../shared/widgets/app_video_player.dart';
import '../../shared/widgets/app_back_button.dart';

class FriendDetailPage extends StatefulWidget {
  final Map<String, dynamic> friendData;
  final MomentsRepository? momentsRepository;

  const FriendDetailPage({
    Key? key,
    required this.friendData,
    this.momentsRepository,
  }) : super(key: key);

  @override
  _FriendDetailPageState createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  final GlobalKey _popupButtonKey = GlobalKey();
  final GlobalUtil _globalUtil = GlobalUtil();
  late final MomentsRepository _momentsRepository;
  Moment? _latestVisibleMoment;
  bool _isLoadingMoments = true;
  bool _momentLoadFailed = false;

  String get _targetUserName =>
      widget.friendData['userName']?.toString().trim() ?? '';

  String get _displayName {
    final remark = widget.friendData['remark']?.toString().trim() ?? '';
    final nickname = widget.friendData['nickname']?.toString().trim() ?? '';
    if (_isFriend && remark.isNotEmpty) return remark;
    return nickname.isEmpty ? _targetUserName : nickname;
  }

  @override
  void initState() {
    super.initState();
    _momentsRepository =
        widget.momentsRepository ?? ServerMomentsRepository.instance;
    _loadMomentPreview();
  }

  Future<void> _loadMomentPreview() async {
    if (_targetUserName.isEmpty) {
      _isLoadingMoments = false;
      return;
    }
    try {
      final moments = await _momentsRepository.fetchUserMoments(
        _targetUserName,
        maxItems: 1,
      );
      if (!mounted) return;
      setState(() {
        _latestVisibleMoment = moments.isEmpty ? null : moments.first;
        _isLoadingMoments = false;
        _momentLoadFailed = false;
      });
    } catch (error) {
      debugPrint('加载好友动态预览失败: $error');
      if (!mounted) return;
      setState(() {
        _isLoadingMoments = false;
        _momentLoadFailed = true;
      });
    }
  }

  bool get _isFriend {
    final explicitValue = widget.friendData['isFriend'];
    if (explicitValue is bool) {
      return explicitValue;
    }
    final userName = widget.friendData['userName']?.toString() ?? '';
    final friendList = _globalUtil.userInfoModel.friendListData;
    return friendList?.any((friend) => friend.userName == userName) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const AppBackButton(),
        toolbarHeight: 50,
        actions: _isFriend
            ? [
                PopupMenuButton<String>(
                  key: _popupButtonKey,
                  icon: Icon(Icons.more_horiz, color: Colors.black),
                  offset: Offset(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'editRemark',
                      child: Text('修改备注'),
                    ),
                    PopupMenuItem<String>(
                      value: 'deleteChatHistory',
                      child: Text('删除聊天记录'),
                    ),
                    PopupMenuItem<String>(
                      value: 'deleteFriend',
                      child: Text('删除好友'),
                    ),
                  ],
                  onSelected: (String value) {
                    if (value == 'editRemark') {
                      _showEditRemarkDialog();
                    } else if (value == 'deleteChatHistory') {
                      _showDeleteChatHistoryDialog();
                    } else if (value == 'deleteFriend') {
                      _showDeleteFriendDialog();
                    }
                  },
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 好友信息区域
            _buildFriendInfoSection(),

            SizedBox(height: 32),

            _buildMomentsSection(),

            SizedBox(height: 40),

            // 操作按钮区域
            _buildActionButtons(),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // 构建好友信息区域
  Widget _buildFriendInfoSection() {
    final remark = widget.friendData['remark']?.toString().trim() ?? '';
    final nickname = widget.friendData['nickname']?.toString().trim() ?? '';
    final signature = widget.friendData['signature']?.toString().trim() ?? '';
    final displayName = _isFriend && remark.isNotEmpty
        ? remark
        : (nickname.isEmpty ? '未知用户' : nickname);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          // 头像
          _buildAvatar(),

          SizedBox(width: 16),

          // 好友信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '昵称: ${nickname.isEmpty ? '未知' : nickname}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                SizedBox(height: 2),
                Text(
                  '帐号: ${widget.friendData['userName'] ?? 'unknown'}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                if (signature.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    '签名: $signature',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),

          // 地区信息
          // Container(
          //   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          //   decoration: BoxDecoration(
          //     color: Colors.blue[100],
          //     borderRadius: BorderRadius.circular(4),
          //   ),
          //   child: Text(
          //     widget.friendData['region'] ?? '北京',
          //     style: TextStyle(fontSize: 12, color: Colors.blue[600]),
          //   ),
          // ),
        ],
      ),
    );
  }

  // 构建朋友圈区域
  Widget _buildMomentsSection() {
    final previewImages =
        _latestVisibleMoment?.mediaPaths.take(6).toList() ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('friend_moments_section'),
            borderRadius: BorderRadius.circular(8),
            onTap: _viewAllMoments,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.photo_library_outlined, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '好友动态',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '进入空间',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          if (_isLoadingMoments ||
              _momentLoadFailed ||
              _latestVisibleMoment != null)
            const SizedBox(height: 14),
          if (_isLoadingMoments)
            const SizedBox(
              height: 72,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_momentLoadFailed)
            GestureDetector(
              onTap: _viewAllMoments,
              child: _buildMomentStatus('动态加载失败，点击进入空间重试'),
            )
          else if (_latestVisibleMoment == null)
            const SizedBox.shrink()
          else ...[
            if (previewImages.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: previewImages.length,
                itemBuilder: (context, index) =>
                    isVideoPath(previewImages[index])
                    ? AppVideoPreview(
                        source: previewImages[index],
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : GestureDetector(
                        onTap: () => showFullscreenImage(
                          context,
                          imageProvider: AppImageCache.provider(
                            previewImages[index],
                          ),
                        ),
                        child: ClipRRect(
                          key: ValueKey('friend_moment_preview_image_$index'),
                          borderRadius: BorderRadius.circular(8),
                          child: Image(
                            image: AppImageCache.provider(previewImages[index]),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: Colors.grey[200]!,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            if (_latestVisibleMoment!.content.isNotEmpty) ...[
              if (previewImages.isNotEmpty) const SizedBox(height: 10),
              Text(
                _latestVisibleMoment!.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700], height: 1.4),
              ),
            ],
            if (previewImages.isEmpty && _latestVisibleMoment!.content.isEmpty)
              _buildMomentStatus('最近一条动态暂无图片'),
          ],
        ],
      ),
    );
  }

  Widget _buildMomentStatus(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600], fontSize: 14),
      ),
    );
  }

  // 构建操作按钮区域
  Widget _buildActionButtons() {
    if (!_isFriend) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _addFriend,
          icon: Icon(Icons.person_add_alt_1),
          label: Text('添加好友'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      );
    }
    return Row(
      children: [
        // 音视频通信按钮
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _startVideoCall(),
              icon: Icon(Icons.video_call, size: 20),
              label: Text('音视频通信'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ),

        SizedBox(width: 16),

        // 发送信息按钮
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () => _sendMessage(),
              icon: Icon(Icons.message, size: 20),
              label: Text('发送信息'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addFriend() {
    Navigator.pushNamed(
      context,
      '/addFriendRequestPage',
      arguments: {
        'avatar': widget.friendData['avatar'] ?? '',
        'nickname': widget.friendData['nickname'] ?? '',
        'phone': widget.friendData['userName'] ?? '',
        'signature': widget.friendData['signature'] ?? '',
      },
    );
  }

  // 显示修改备注对话框
  void _showEditRemarkDialog() {
    TextEditingController remarkController = TextEditingController(
      text: widget.friendData['remark'] ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('修改备注'),
          content: TextField(
            controller: remarkController,
            decoration: InputDecoration(
              hintText: '请输入新备注',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                // 获取当前用户和好友的UserName
                String currentUserName = _globalUtil.userName ?? '';
                String friendUserName = widget.friendData['userName'] ?? '';
                String newRemark = remarkController.text.trim();

                if (currentUserName.isEmpty || friendUserName.isEmpty) {
                  _showMessage('获取用户信息失败');
                  return;
                }

                try {
                  // 调用修改备注API
                  Map<String, dynamic> response = await updateFriendRemarkApi(
                    currentUserName,
                    friendUserName,
                    newRemark,
                  );
                  if (!mounted || !context.mounted) return;

                  // 检查返回结果
                  if (response['code'] == 100) {
                    _globalUtil.updateCachedFriendRemark(
                      friendUserName,
                      newRemark,
                    );
                    setState(() {
                      widget.friendData['remark'] = newRemark;
                    });
                    Navigator.pop(context);
                    _showMessage('备注修改成功');
                  } else {
                    _showMessage('备注修改失败');
                  }
                } catch (e) {
                  debugPrint('修改备注失败: $e');
                  _showMessage('备注修改失败，请重试');
                }
              },
              child: Text('确认'),
            ),
          ],
        );
      },
    );
  }

  // 显示删除聊天记录对话框
  void _showDeleteChatHistoryDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除聊天记录'),
        content: Text('将永久删除你与该好友在服务器和本机保存的全部聊天记录，双方均无法再查看。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final currentUserName = _globalUtil.userName ?? '';
              if (currentUserName.isEmpty || _targetUserName.isEmpty) {
                _showMessage('获取用户信息失败');
                return;
              }
              try {
                final sessionId = GlobalUtil.generateSessionId(
                  currentUserName,
                  _targetUserName,
                );
                final response = await deletePrivateChatHistoryApi(
                  userName: currentUserName,
                  peerUserName: _targetUserName,
                  conversationId: sessionId,
                );
                if (response['code'] != 100) {
                  throw Exception(response['msg'] ?? '服务器删除失败');
                }
                await _globalUtil.deleteChatRecords(_targetUserName);
                if (mounted) _showMessage('聊天记录已删除');
              } catch (error) {
                debugPrint('删除聊天记录失败: $error');
                if (mounted) _showMessage('删除聊天记录失败，请重试');
              }
            },
            child: Text('删除'),
          ),
        ],
      ),
    );
  }

  // 显示删除好友对话框
  void _showDeleteFriendDialog() {
    // 保存页面context以便在对话框内部使用
    final pageContext = context;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('删除好友'),
          content: Text('确定要删除该好友吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // 获取当前用户和好友的UserName
                String currentUserName = _globalUtil.userName ?? '';
                String friendUserName = widget.friendData['userName'] ?? '';

                if (currentUserName.isEmpty || friendUserName.isEmpty) {
                  _showMessage('获取用户信息失败');
                  return;
                }

                try {
                  // 生成会话ID
                  String sessionId = GlobalUtil.generateSessionId(
                    currentUserName,
                    friendUserName,
                  );

                  // 调用删除好友API
                  Map<String, dynamic> response = await handledeleteFriendApi(
                    currentUserName,
                    friendUserName,
                    sessionId,
                  );

                  // 检查返回结果
                  if (response['code'] == 100) {
                    _showMessage('好友删除成功');
                    // 返回上一页，使用页面context
                    Navigator.pop(pageContext);
                  } else {
                    _showMessage('好友删除失败');
                  }
                } catch (e) {
                  debugPrint('删除好友失败: $e');
                  _showMessage('删除好友失败，请重试');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('确认'),
            ),
          ],
        );
      },
    );
  }

  // 查看全部朋友圈
  void _viewAllMoments() {
    if (_targetUserName.isEmpty) {
      _showMessage('用户信息不完整');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyMomentsPage(
          repository: _momentsRepository,
          userId: _targetUserName,
          displayName: _displayName,
          avatarUrl: _resolvedAvatarUrl(),
          allowPublishing: false,
          pageTitle: '$_displayName的空间',
        ),
      ),
    );
  }

  // 发送信息
  void _sendMessage() {
    String testPuname = widget.friendData['userName'];
    debugPrint("testPuname = $testPuname");
    Navigator.pushNamed(
      context,
      '/chatDialog',
      arguments: widget.friendData['userName'],
    );
  }

  // 发起视频通话
  void _startVideoCall() {
    String friendUserName = widget.friendData['userName'] ?? '';
    if (friendUserName.isEmpty) {
      _showMessage('获取好友信息失败');
      return;
    }

    // 使用friendUserName作为频道名称
    String channelName = friendUserName;
    // 在实际应用中，token应该从服务器获取
    // 这里使用临时token（在Agora测试环境中可以使用临时token）
    const token = '';

    // 发送视频通话邀请
    final wsManager = WebSocketManager();
    if (wsManager.isConnected) {
      wsManager.send({
        'type': 'videoCallInvite',
        'receiver': friendUserName,
        'sender': GlobalUtil().userName,
        'channelName': channelName,
        'token': token,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
    }

    // 跳转到视频通话页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VideoCallPage(channelName: channelName, token: token),
      ),
    );
  }

  // 构建头像，实现缓存机制
  Widget _buildAvatar() {
    final avatarUrl = _resolvedAvatarUrl();
    if (avatarUrl.isEmpty) {
      final nickname = widget.friendData['nickname']?.toString() ?? '';
      final initial = nickname.trim().isEmpty
          ? '?'
          : nickname.trim().characters.first;
      return CircleAvatar(radius: 30, child: Text(initial));
    }

    return CircleAvatar(
      radius: 30,
      backgroundImage: AppImageCache.provider(avatarUrl),
    );
  }

  String _resolvedAvatarUrl() {
    String avatarUrl = widget.friendData['avatar']?.toString() ?? '';
    if (avatarUrl.isNotEmpty &&
        !avatarUrl.startsWith('http://') &&
        !avatarUrl.startsWith('https://')) {
      try {
        avatarUrl = _globalUtil.getImageURL(_targetUserName, avatarUrl);
      } catch (error) {
        debugPrint('生成资料页头像地址失败: $error');
        avatarUrl = '';
      }
    }
    return avatarUrl;
  }

  // 显示提示信息
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }
}
