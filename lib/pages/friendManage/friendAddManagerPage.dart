import 'package:flutter/material.dart';
import '../../model/friendRequestModel.dart';
import '../../utils/Gloabl.dart';
import '../../api/getFriendRequestsAPI.dart';
import '../../core/cache/app_image_cache.dart';

class FriendAddManagerPage extends StatefulWidget {
  final List<FriendRequestModel>? initialRequests;

  const FriendAddManagerPage({Key? key, this.initialRequests})
    : super(key: key);

  @override
  _FriendAddManagerPageState createState() => _FriendAddManagerPageState();
}

class _FriendAddManagerPageState extends State<FriendAddManagerPage> {
  // 验证申请数据
  List<FriendRequestModel> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    // 使用传递过来的初始请求数据，如果没有则使用默认的模拟数据
    if (widget.initialRequests != null && widget.initialRequests!.isNotEmpty) {
      _pendingRequests = widget.initialRequests!;

      // 当进入页面时，为所有好友申请发送requestResult=4的请求
      _sendAllRequestsSeen();
    } else {
      _pendingRequests = [
        // FriendRequestModel(
        //   requestId: 1,
        //   userName: 'user001',
        //   nickName: '李四',
        //   verificationMessage: '我是李四，我们之前见过面',
        //   requestTime: DateTime.now().subtract(Duration(hours: 2)),
        // ),
        // FriendRequestModel(
        //   requestId: 2,
        //   userName: 'user002',
        //   nickName: '王五',
        //   verificationMessage: '通过朋友介绍，想和你成为好友',
        //   requestTime: DateTime.now().subtract(Duration(hours: 5)),
        // ),
        // FriendRequestModel(
        //   requestId: 3,
        //   userName: 'user003',
        //   nickName: '赵六',
        //   verificationMessage: '同学，想加个好友',
        //   requestTime: DateTime.now().subtract(Duration(days: 1)),
        // ),
      ];
    }
    // 在_pendingRequests赋值之后打印大小
    int size = _pendingRequests.length;
    debugPrint("xxxxxxxxx ==$size");

    // 获取当前用户信息并加载最近好友列表
    _loadRecentFriends();
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
  List<RecentFriendModel> _recentFriends = [
    RecentFriendModel(
      userName: 'friend001',
      nickName: '孙七',
      addTime: DateTime.now()
          .subtract(Duration(hours: 1))
          .millisecondsSinceEpoch,
      remarks: '大学同学',
    ),
    RecentFriendModel(
      userName: 'friend002',
      nickName: '周八',
      addTime: DateTime.now()
          .subtract(Duration(days: 1, hours: 3))
          .millisecondsSinceEpoch,
      remarks: '同事',
    ),
    RecentFriendModel(
      userName: 'friend003',
      nickName: '吴九',
      addTime: DateTime.now()
          .subtract(Duration(days: 2, hours: 5))
          .millisecondsSinceEpoch,
    ),
    RecentFriendModel(
      userName: 'friend004',
      nickName: '郑十',
      addTime: DateTime.now()
          .subtract(Duration(days: 3, hours: 2))
          .millisecondsSinceEpoch,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('好友验证', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 验证申请部分
          _buildVerificationSection(),

          // 最近添加的好友部分
          _buildRecentFriendsSection(),
        ],
      ),
    );
  }

  Widget _buildVerificationSection() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '验证申请',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (_pendingRequests.isEmpty)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Text('暂无验证申请', style: TextStyle(color: Colors.grey)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _pendingRequests.length,
              itemBuilder: (context, index) {
                return _buildRequestItem(_pendingRequests[index]);
              },
            ),
          Divider(height: 1, color: Colors.grey[200]),
        ],
      ),
    );
  }

  Widget _buildRecentFriendsSection() {
    return Expanded(
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '最近添加',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (_recentFriends.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    '最近没有添加新好友',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _recentFriends.length,
                  itemBuilder: (context, index) {
                    return _buildFriendItem(_recentFriends[index]);
                  },
                ),
              ),
          ],
        ),
      ),
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
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          CircleAvatar(
            radius: 30,
            backgroundImage: isNetworkImage
                ? AppImageCache.provider(avatarUrl)
                : null,
            child: isNetworkImage
                ? null
                : Text(
                    isNetworkImage ? '' : avatarUrl,
                    style: TextStyle(fontSize: 24),
                  ),
            backgroundColor: Colors.grey[200],
          ),
          SizedBox(width: 12),

          // 信息和按钮区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      request.nickName ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatTime(request.requestTime ?? DateTime.now()),
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  request.verificationMessage ?? '',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 12),

                // 同意和拒绝按钮
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleAccept(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text('同意'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleReject(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        child: Text('拒绝'),
                      ),
                    ),
                  ],
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

    return ListTile(
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: isNetworkImage
            ? AppImageCache.provider(avatarUrl)
            : null,
        child: isNetworkImage
            ? null
            : Text(avatarUrl, style: TextStyle(fontSize: 20)),
        backgroundColor: Colors.grey[200],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              friend.nickName ?? '',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            _formatTime(
              friend.addTime != null
                  ? DateTime.fromMillisecondsSinceEpoch(friend.addTime!)
                  : DateTime.now(),
            ),
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      subtitle: Text(
        friend.remarks ?? '',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      onTap: () {
        // 点击进入好友详情
        _showFriendDetail(friend);
      },
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
