import 'package:flutter/material.dart';
import '../../api/getFriendRequestsAPI.dart';
import '../../utils/gloabl.dart';
import '../../utils/WebSocketManager.dart';
import '../videoCallPage.dart';

class FriendDetailPage extends StatefulWidget {
  final Map<String, dynamic> friendData;

  const FriendDetailPage({Key? key, required this.friendData})
    : super(key: key);

  @override
  _FriendDetailPageState createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  final GlobalKey _popupButtonKey = GlobalKey();
  final GlobalUtil _globalUtil = GlobalUtil();

  // 头像 URL 缓存，用于避免重复加载
  Map<String, String> _avatarCache = {};

  // 模拟朋友圈数据
  final List<String> _momentImages = [
    'https://images.unsplash.com/photo-1518837695005-2083093ee35b?w=300&h=300&fit=crop',
    'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=300&h=300&fit=crop',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=300&fit=crop',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=300&h=300&fit=crop',
    'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=300&h=300&fit=crop',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300&h=300&fit=crop',
  ];

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
        automaticallyImplyLeading: true,
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
                      value: 'deleteFriend',
                      child: Text('删除好友'),
                    ),
                  ],
                  onSelected: (String value) {
                    if (value == 'editRemark') {
                      _showEditRemarkDialog();
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

            // 非好友只能看到基础资料，不能查看动态详情。
            _isFriend ? _buildMomentsSection() : _buildPrivateMomentsSection(),

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.grey[600], size: 20),
            SizedBox(width: 8),
            Text(
              '好友动态',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        SizedBox(height: 16),

        // 朋友圈图片网格
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _momentImages.length > 6 ? 6 : _momentImages.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => _viewMomentDetail(index),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _momentImages[index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[400]),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),

        if (_momentImages.length > 6)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12),
            child: TextButton(
              onPressed: () => _viewAllMoments(),
              child: Text('查看更多朋友圈', style: TextStyle(color: Colors.blue)),
            ),
          ),
      ],
    );
  }

  Widget _buildPrivateMomentsSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.lock_outline, color: Colors.grey[500], size: 28),
          SizedBox(height: 8),
          Text(
            '添加好友后可查看动态',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
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
                String newRemark = remarkController.text;

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

                  // 检查返回结果
                  if (response['code'] == 100) {
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

  // 查看朋友圈详情
  void _viewMomentDetail(int index) {
    _showMessage('查看朋友圈详情 $index');
  }

  // 查看全部朋友圈
  void _viewAllMoments() {
    _showMessage('查看全部朋友圈');
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
    String userName = widget.friendData['userName'] ?? "";
    String avatarUrl = widget.friendData['avatar'] ?? '';
    if (avatarUrl.isNotEmpty &&
        !avatarUrl.startsWith('http://') &&
        !avatarUrl.startsWith('https://')) {
      try {
        avatarUrl = _globalUtil.getImageURL(userName, avatarUrl);
      } catch (error) {
        debugPrint('生成资料页头像地址失败: $error');
        avatarUrl = '';
      }
    }

    if (avatarUrl.isEmpty) {
      final nickname = widget.friendData['nickname']?.toString() ?? '';
      final initial = nickname.trim().isEmpty
          ? '?'
          : nickname.trim().characters.first;
      return CircleAvatar(radius: 30, child: Text(initial));
    }

    // 检查缓存中是否已有该用户的头像，并且 URL 是否相同
    if (_avatarCache.containsKey(userName)) {
      String cachedUrl = _avatarCache[userName]!;
      if (cachedUrl == avatarUrl) {
        // URL 相同，使用缓存的头像 URL
        return CircleAvatar(
          radius: 30,
          backgroundImage: NetworkImage(cachedUrl),
        );
      } else {
        // URL 不同，使用新的头像 URL 并更新缓存
        _avatarCache[userName] = avatarUrl;
        return CircleAvatar(
          radius: 30,
          backgroundImage: NetworkImage(avatarUrl),
        );
      }
    } else {
      // 缓存中没有，使用新的头像 URL 并加入缓存
      _avatarCache[userName] = avatarUrl;
      return CircleAvatar(radius: 30, backgroundImage: NetworkImage(avatarUrl));
    }
  }

  // 显示提示信息
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }
}
