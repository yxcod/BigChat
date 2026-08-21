import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_base/utils/agoraManager.dart';
import 'package:flutter_base/utils/WebSocketManager.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as dev;

class VideoCallPage extends StatefulWidget {
  final String channelName;
  final String token;

  const VideoCallPage({
    super.key,
    required this.channelName,
    required this.token,
  });

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final AgoraManager _agoraManager = AgoraManager();
  WebSocketMessageSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    // 初始化并加入频道
    _initAndJoinChannel();
    // 设置WebSocket消息监听器
    _setupWebSocketListener();
  }

  @override
  void dispose() {
    // 移除WebSocket消息监听器
    _messageSubscription?.cancel();
    super.dispose();
  }

  // 请求权限
  Future<bool> _requestPermissions() async {
    final cameraPermission = await Permission.camera.request();
    final microphonePermission = await Permission.microphone.request();

    if (cameraPermission.isGranted && microphonePermission.isGranted) {
      return true;
    } else {
      // 如果权限被拒绝，显示提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要摄像头和麦克风权限才能进行视频通话'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return false;
    }
  }

  // 初始化并加入频道
  Future<void> _initAndJoinChannel() async {
    // 请求权限
    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) return;

    try {
      // 初始化 Agora 引擎
      await _agoraManager.initialize(context);

      // 加入频道
      await _agoraManager.joinChannel(
        channelName: widget.channelName,
        token: widget.token,
      );
    } catch (e) {
      dev.log('初始化和加入频道失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('视频通话初始化失败: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  // 设置WebSocket消息监听器
  void _setupWebSocketListener() {
    final wsManager = WebSocketManager();
    // 不重新连接，只设置消息监听器
    // 因为WebSocketManager是单例，应该已经在应用启动时连接了
    _messageSubscription = wsManager.addMessageListener(
      _handleWebSocketMessage,
    );
  }

  // 处理WebSocket消息
  void _handleWebSocketMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      final messageType = message['type'] ?? '';
      //final channelName = message['channelName'] ?? '';

      // 处理挂断消息和拒绝消息，不需要检查channelName
      // 因为这些消息是针对当前通话的
      if (messageType == 'videoCallHangup' ||
          messageType == 'videoCallReject') {
        dev.log(
          '收到${messageType == 'videoCallHangup' ? '挂断' : '拒绝'}消息，关闭视频通话页面',
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  // 离开频道并释放资源
  Future<void> _leaveChannel() async {
    try {
      // 离开频道
      await _agoraManager.leaveChannel();

      // 释放 Agora 引擎
      await _agoraManager.dispose();
    } catch (e) {
      dev.log('离开频道并释放资源失败: $e');
    }
  }

  // 构建本地视频视图
  Widget _buildLocalVideoView() {
    final engine = _agoraManager.engine;
    if (engine == null) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: const Center(child: Text('视频引擎正在初始化...')),
        ),
      );
    }

    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey, width: 1),
        ),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: engine,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ),
    );
  }

  // 构建远程视频视图
  Widget _buildRemoteVideoView() {
    final remoteUids = _agoraManager.remoteUids.toList();
    final engine = _agoraManager.engine;

    if (remoteUids.isEmpty) {
      // 如果没有远程用户，显示提示
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: const Center(child: Text('等待对方加入...')),
        ),
      );
    } else if (engine == null) {
      // 如果引擎为 null，显示提示
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: const Center(child: Text('视频引擎正在初始化...')),
        ),
      );
    } else {
      // 构建远程视频视图
      final uid = remoteUids.first;

      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey, width: 1),
          ),
          child: AgoraVideoView(
            controller: VideoViewController(
              rtcEngine: engine,
              canvas: VideoCanvas(uid: uid),
            ),
          ),
        ),
      );
    }
  }

  // 构建视频网格
  Widget _buildVideoGrid() {
    final remoteUids = _agoraManager.remoteUids;
    final engine = _agoraManager.engine;

    if (engine == null) {
      // 如果引擎为 null，显示提示
      return const Expanded(child: Center(child: Text('视频引擎正在初始化...')));
    }

    if (remoteUids.isEmpty) {
      // 只有本地用户
      return _buildLocalVideoView();
    } else if (remoteUids.length == 1) {
      // 本地用户和一个远程用户
      return Column(
        children: [_buildRemoteVideoView(), _buildLocalVideoView()],
      );
    } else {
      // 本地用户和多个远程用户
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: 1 + remoteUids.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildLocalVideoView();
          } else {
            final uid = remoteUids.elementAt(index - 1);

            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey, width: 1),
              ),
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: uid),
                ),
              ),
            );
          }
        },
      );
    }
  }

  // 构建控制按钮
  Widget _buildControlButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 切换摄像头按钮
          FloatingActionButton(
            onPressed: () {
              _agoraManager.switchCamera();
            },
            heroTag: 'switch_camera',
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            child: const Icon(Icons.switch_camera),
          ),

          // 开关麦克风按钮
          FloatingActionButton(
            onPressed: () {
              _agoraManager.toggleLocalAudio();
              setState(() {});
            },
            heroTag: 'toggle_mic',
            backgroundColor: _agoraManager.isLocalAudioEnabled
                ? Colors.white
                : Colors.red,
            foregroundColor: Colors.blue,
            child: Icon(
              _agoraManager.isLocalAudioEnabled ? Icons.mic : Icons.mic_off,
            ),
          ),

          // 挂断按钮
          FloatingActionButton(
            onPressed: () async {
              // 发送挂断消息
              final wsManager = WebSocketManager();
              if (wsManager.isConnected) {
                wsManager.send({
                  'type': 'videoCallHangup',
                  'receiver': widget.channelName, // 使用channelName作为接收者
                  'sender': GlobalUtil().userName,
                  'channelName': widget.channelName,
                  'time': DateTime.now().millisecondsSinceEpoch,
                });
                dev.log('发送视频通话挂断消息');
              }

              // 先离开频道并释放资源
              await _leaveChannel();

              // 关闭视频通话页面
              Navigator.of(context).pop();
            },
            heroTag: 'hang_up',
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            child: const Icon(Icons.call_end),
          ),

          // 开关摄像头按钮
          FloatingActionButton(
            onPressed: () {
              _agoraManager.toggleLocalVideo();
              setState(() {});
            },
            heroTag: 'toggle_camera',
            backgroundColor: _agoraManager.isLocalVideoEnabled
                ? Colors.white
                : Colors.red,
            foregroundColor: Colors.blue,
            child: Icon(
              _agoraManager.isLocalVideoEnabled
                  ? Icons.videocam
                  : Icons.videocam_off,
            ),
          ),

          // 扬声器/听筒切换按钮
          FloatingActionButton(
            onPressed: () {
              // 这个功能可以在 AgoraManager 中添加
            },
            heroTag: 'speaker',
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            child: const Icon(Icons.volume_up),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('视频通话 - ${widget.channelName}'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 视频区域
          Expanded(child: _buildVideoGrid()),
          // 控制按钮区域
          _buildControlButtons(),
        ],
      ),
    );
  }
}
