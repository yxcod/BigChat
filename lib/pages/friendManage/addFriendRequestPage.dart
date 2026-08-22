import 'package:flutter/material.dart';
import '../../api/getFriendRequestsAPI.dart';
import '../../utils/gloabl.dart';
import '../../core/cache/app_image_cache.dart';

class AddFriendRequestPage extends StatefulWidget {
  final Map<String, dynamic> targetUser;

  const AddFriendRequestPage({Key? key, required this.targetUser})
    : super(key: key);

  @override
  _AddFriendRequestPageState createState() => _AddFriendRequestPageState();
}

class _AddFriendRequestPageState extends State<AddFriendRequestPage> {
  final TextEditingController _requestController = TextEditingController();
  final FocusNode _requestFocusNode = FocusNode();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // 默认的验证消息
    _requestController.text = '你好，我想加你为好友';
    // 自动聚焦到输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_requestFocusNode);
    });
  }

  @override
  void dispose() {
    _requestController.dispose();
    _requestFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('添加好友'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 目标用户信息
          _buildTargetUserInfo(),

          SizedBox(height: 12),

          // 验证消息区域
          _buildRequestMessageSection(),

          // 发送按钮
          Padding(padding: EdgeInsets.only(top: 4), child: _buildSendButton()),
        ],
      ),
    );
  }

  // 构建目标用户信息
  Widget _buildTargetUserInfo() {
    final avatarUrl = widget.targetUser['avatar']?.toString() ?? '';
    final nickname = widget.targetUser['nickname']?.toString() ?? '';
    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            spreadRadius: 1,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 用户头像
          CircleAvatar(
            radius: 25,
            backgroundImage: avatarUrl.isEmpty
                ? null
                : AppImageCache.provider(avatarUrl),
            backgroundColor: Colors.grey[200],
            child: avatarUrl.isEmpty
                ? Text(
                    nickname.trim().isEmpty
                        ? '?'
                        : nickname.trim().characters.first,
                  )
                : null,
          ),

          SizedBox(width: 12),

          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.targetUser['nickname'] ?? '未知用户',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  '手机号: ${widget.targetUser['phone'] ?? 'unknown'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (widget.targetUser['region'] != null) ...[
                  SizedBox(height: 2),
                  Text(
                    '地区: ${widget.targetUser['region']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建验证消息区域
  Widget _buildRequestMessageSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '验证消息',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),

          // 输入框
          Container(
            height: 120,
            child: TextField(
              controller: _requestController,
              focusNode: _requestFocusNode,
              maxLines: null,
              maxLength: 200,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (value) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: '请输入验证消息，让对方知道你是谁...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.all(12),
                counterText: '', // 完全隐藏TextField默认的字数统计
              ),
            ),
          ),

          SizedBox(height: 8),

          // 字数统计
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              '${_requestController.text.length}/200',
              style: TextStyle(fontSize: 12, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // 构建发送按钮
  Widget _buildSendButton() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: _isSending ? null : _sendFriendRequest,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 2,
          ),
          child: _isSending
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('发送中...'),
                  ],
                )
              : Text(
                  '发送添加好友请求',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
        ),
      ),
    );
  }

  // 发送好友请求
  void _sendFriendRequest() {
    String message = _requestController.text.trim();

    if (message.isEmpty) {
      _showSnackBar('请输入验证消息', Colors.orange);
      return;
    }

    if (message.length < 2) {
      _showSnackBar('验证消息太短，请输入更多信息', Colors.orange);
      return;
    }

    setState(() {
      _isSending = true;
    });

    // 获取当前用户信息和目标用户信息
    final currentUserName = GlobalUtil().userName;
    final targetUserName = widget.targetUser['phone'];

    if (currentUserName == null || currentUserName.isEmpty) {
      setState(() {
        _isSending = false;
      });
      _showSnackBar('当前用户信息缺失', Colors.red);
      return;
    }

    if (targetUserName == null || targetUserName.isEmpty) {
      setState(() {
        _isSending = false;
      });
      _showSnackBar('目标用户信息缺失', Colors.red);
      return;
    }

    // 调用API发送好友请求
    sendFriendRequestApi(currentUserName, targetUserName, message)
        .then((success) {
          setState(() {
            _isSending = false;
          });

          _showSnackBar('好友请求已发送', Colors.green);

          // 返回上一页
          Navigator.pop(context);
        })
        .catchError((error) {
          setState(() {
            _isSending = false;
          });

          _showSnackBar('发送好友请求失败', Colors.red);
          debugPrint('发送好友请求失败: $error');
        });
  }

  // 显示提示信息
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}
