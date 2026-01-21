import 'package:flutter/material.dart';
import 'package:flutter_base/utils/WebSocketManager.dart';
import 'package:flutter_base/utils/Gloabl.dart';
import 'videoCallPage.dart';

class VideoCallInviteWaitingPage extends StatefulWidget {
  final String inviterName;
  final String inviterUsername;
  final String channelName;
  final String token;

  const VideoCallInviteWaitingPage({
    super.key,
    required this.inviterName,
    required this.inviterUsername,
    required this.channelName,
    required this.token,
  });

  @override
  State<VideoCallInviteWaitingPage> createState() =>
      _VideoCallInviteWaitingPageState();
}

class _VideoCallInviteWaitingPageState
    extends State<VideoCallInviteWaitingPage> {
  late WebSocketManager _wsManager;
  late Function(dynamic) _messageListener;

  @override
  void initState() {
    super.initState();
    _wsManager = WebSocketManager();
    // 添加WebSocket消息监听器
    _messageListener = (message) {
      _handleWebSocketMessage(message);
    };
    _wsManager.setMessageListener(_messageListener);
  }

  @override
  void dispose() {
    // 移除WebSocket消息监听器
    _wsManager.removeMessageListener(_messageListener);
    super.dispose();
  }

  // 处理WebSocket消息
  void _handleWebSocketMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      final messageType = message['type'] ?? '';
      final channelName = message['channelName'] ?? '';

      // 处理挂断消息
      if (messageType == 'videoCallHangup' &&
          channelName == widget.channelName) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 邀请者头像
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: ClipOval(
                child: Image.network(
                  GlobalUtil().getImageURL(widget.inviterUsername, "head.jpg"),
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: Text(
                        widget.inviterName.isNotEmpty
                            ? widget.inviterName[0].toUpperCase()
                            : '?',
                        style: TextStyle(fontSize: 40, color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        widget.inviterName.isNotEmpty
                            ? widget.inviterName[0].toUpperCase()
                            : '?',
                        style: TextStyle(fontSize: 40, color: Colors.white),
                      ),
                    );
                  },
                ),
              ),
            ),

            SizedBox(height: 20),

            // 邀请者名称
            Text(
              widget.inviterName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 10),

            // 邀请状态
            Text(
              '正在邀请您...',
              style: TextStyle(color: Colors.grey, fontSize: 18),
            ),

            SizedBox(height: 80),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 拒绝按钮
                GestureDetector(
                  onTap: () {
                    _rejectCall(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.call_end,
                            size: 40,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '拒绝',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ],
                  ),
                ),

                // 接受按钮
                GestureDetector(
                  onTap: () {
                    _acceptCall(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.videocam,
                            size: 40,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '接受',
                        style: TextStyle(color: Colors.green, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 拒绝通话
  void _rejectCall(BuildContext context) {
    if (_wsManager.isConnected) {
      _wsManager.send({
        'type': 'videoCallReject',
        'receiver': widget.inviterUsername,
        'sender': GlobalUtil().userName,
        'channelName': widget.channelName,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
    }
    Navigator.pop(context);
  }

  // 接受通话
  void _acceptCall(BuildContext context) {
    if (_wsManager.isConnected) {
      _wsManager.send({
        'type': 'videoCallAccept',
        'receiver': widget.inviterUsername,
        'sender': GlobalUtil().userName,
        'channelName': widget.channelName,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
    }
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            VideoCallPage(channelName: widget.channelName, token: widget.token),
      ),
    );
  }
}
