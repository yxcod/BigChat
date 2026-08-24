import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../core/cache/app_image_cache.dart';
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
import 'friendSettingsPage.dart';
import '../../model/userInfoModel.dart';

class FriendDetailPage extends StatefulWidget {
  final Map<String, dynamic> friendData;
  final MomentsRepository? momentsRepository;
  final Future<UserInfoModel> Function(String userName)? profileLoader;

  const FriendDetailPage({
    Key? key,
    required this.friendData,
    this.momentsRepository,
    this.profileLoader,
  }) : super(key: key);

  @override
  _FriendDetailPageState createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  final GlobalUtil _globalUtil = GlobalUtil();
  late final MomentsRepository _momentsRepository;
  Moment? _latestVisibleMoment;
  bool _isLoadingMoments = true;
  bool _momentLoadFailed = false;
  late int _gender;
  late String _region;

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
    _gender = int.tryParse(widget.friendData['gender']?.toString() ?? '') ?? 0;
    _region = widget.friendData['region']?.toString().trim() ?? '';
    _loadBasicProfile();
    _loadMomentPreview();
  }

  Future<void> _loadBasicProfile() async {
    final loader = widget.profileLoader;
    if (_targetUserName.isEmpty || loader == null) return;
    try {
      final userInfo = await loader(_targetUserName);
      if (!mounted) return;
      setState(() {
        _gender = userInfo.gender;
        _region = userInfo.region.trim();
      });
    } catch (error) {
      debugPrint('加载用户性别和地区失败，使用已有资料: $error');
    }
  }

  Future<void> _loadMomentPreview() async {
    if (_targetUserName.isEmpty) {
      _isLoadingMoments = false;
      return;
    }
    try {
      final moments = await _momentsRepository.fetchUserMoments(
        _targetUserName,
        maxItems: _isFriend ? 1 : 20,
      );
      final visibleMoments = _isFriend
          ? moments
          : moments
                .where((moment) => moment.visibility == MomentVisibility.public)
                .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _latestVisibleMoment = visibleMoments.isEmpty
            ? null
            : visibleMoments.first;
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: const AppBackButton(),
        centerTitle: true,
        toolbarHeight: 56,
        title: const Text('个人资料'),
        actions: _isFriend
            ? [
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.black),
                  tooltip: '好友设置',
                  onPressed: _openFriendSettings,
                ),
              ]
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFriendInfoSection(),
                  _buildMomentsSection(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildBottomActionBar(),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: _buildActionButtons(),
      ),
    );
  }

  Widget _buildProfileMetadata() {
    final items = <Widget>[];
    if (_gender != 0) {
      items.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _gender == 2 ? Icons.female : Icons.male,
              size: 18,
              color: _gender == 2
                  ? const Color(0xFFE875A5)
                  : const Color(0xFF2196F3),
            ),
            const SizedBox(width: 5),
            Text(userGenderLabel(_gender)),
          ],
        ),
      );
    }
    final hasRegion = _region.isNotEmpty;
    items.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on_outlined,
            key: const Key('profile_region_icon'),
            size: 18,
            color: hasRegion ? AppColors.textPrimary : AppColors.textSecondary,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 110,
            ),
            child: Text(
              hasRegion ? _region : '未知',
              key: const Key('profile_region_label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasRegion
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    return Wrap(
      spacing: 18,
      runSpacing: 10,
      children: items
          .map(
            (item) => DefaultTextStyle(
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              child: item,
            ),
          )
          .toList(growable: false),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '账号：${widget.friendData['userName'] ?? 'unknown'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (_isFriend &&
                        remark.isNotEmpty &&
                        nickname.isNotEmpty &&
                        remark != nickname) ...[
                      const SizedBox(height: 5),
                      Text(
                        '昵称：$nickname',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          _buildProfileMetadata(),
          if (signature.isNotEmpty) ...[
            const SizedBox(height: 28),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '个性签名',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    signature,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建朋友圈区域
  Widget _buildMomentsSection() {
    final previewImages =
        _latestVisibleMoment?.mediaPaths.take(6).toList() ?? const <String>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFF4F4F5), width: 10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('friend_moments_section'),
            borderRadius: BorderRadius.circular(10),
            onTap: _viewAllMoments,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '动态',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '查看全部',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
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
            const SizedBox(height: 16),
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
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
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
                          borderRadius: BorderRadius.circular(10),
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
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
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
          key: const Key('profile_add_friend_button'),
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
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _startVideoCall(),
              icon: const Icon(Icons.videocam_outlined, size: 22),
              label: const Text('视频通话'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: Color(0xFFB8B8B8)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => _sendMessage(),
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: const Text('发消息'),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
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

  Future<void> _openFriendSettings() async {
    final result = await Navigator.push<FriendSettingsResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FriendSettingsPage(friendData: widget.friendData),
      ),
    );
    if (!mounted) return;

    final cachedRemark = _globalUtil
        .getFriendInfoByUserName(_targetUserName)
        .remarks
        ?.trim();
    setState(() {
      widget.friendData['remark'] = result?.remark ?? cachedRemark ?? '';
    });
    if (result?.friendDeleted == true) {
      Navigator.pop(context, true);
    }
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
          visibilityFilter: _isFriend ? null : MomentVisibility.public,
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
      return CircleAvatar(radius: 48, child: Text(initial));
    }

    return CircleAvatar(
      radius: 48,
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
