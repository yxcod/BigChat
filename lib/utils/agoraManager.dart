import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

class AgoraManager {
  static final AgoraManager _instance = AgoraManager._internal();
  factory AgoraManager() => _instance;

  AgoraManager._internal();

  // Agora 应用 ID，需要替换为你自己的 App ID
  // 你可以在 Agora 控制台（https://console.agora.io）中创建项目并获取 App ID
  final String appId = '324827b480b6470b8949bf1f317e9096';

  // 初始化的引擎实例
  RtcEngine? _engine;

  // 本地用户 ID
  int? _localUid;

  // 远程用户列表
  final Set<int> _remoteUids = <int>{};

  // 本地视频启用状态
  bool _isLocalVideoEnabled = true;

  // 本地音频启用状态
  bool _isLocalAudioEnabled = true;

  // 初始化 Agora 引擎
  Future<void> initialize(BuildContext context) async {
    try {
      // 如果引擎已经存在，先释放它
      if (_engine != null) {
        await _engine!.release();
        _engine = null;
      }

      // 创建并初始化 Agora 引擎
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(appId: appId));

      // 设置频道场景为通信模式
      await _engine!.setChannelProfile(
        ChannelProfileType.channelProfileCommunication,
      );

      // 设置事件处理
      _setupEventHandlers(context);

      // 启用视频
      await _engine!.enableVideo();

      // 启用音频
      await _engine!.enableAudio();

      // 重置状态变量
      _localUid = null;
      _remoteUids.clear();
      _isLocalVideoEnabled = true;
      _isLocalAudioEnabled = true;

      debugPrint('Agora 引擎初始化成功');
    } catch (e) {
      debugPrint('Agora 引擎初始化失败: $e');
      rethrow;
    }
  }

  // 设置事件处理
  void _setupEventHandlers(BuildContext context) {
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        // 加入频道成功
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('加入频道成功: UID = ${connection.localUid}');
          _localUid = connection.localUid;
        },

        // 离开频道
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('离开频道');
          _remoteUids.clear();
          _localUid = null;
        },

        // 远程用户加入频道
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('远程用户加入: UID = $remoteUid');
          _remoteUids.add(remoteUid);
        },

        // 远程用户离开频道
        onUserOffline:
            (
              RtcConnection connection,
              int remoteUid,
              UserOfflineReasonType reason,
            ) {
              debugPrint('远程用户离开: UID = $remoteUid, 原因 = $reason');
              _remoteUids.remove(remoteUid);
            },

        // 错误
        onError: (ErrorCodeType err, String msg) {
          debugPrint('错误: $err - $msg');
        },
      ),
    );
  }

  // 加入频道
  Future<void> joinChannel({
    required String channelName,
    required String token,
    int uid = 0,
  }) async {
    try {
      // 加入频道
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(),
      );
      debugPrint('成功加入频道: $channelName');
    } catch (e) {
      debugPrint('加入频道失败: $e');
      rethrow;
    }
  }

  // 离开频道
  Future<void> leaveChannel() async {
    try {
      // 离开频道
      await _engine!.leaveChannel();
      debugPrint('成功离开频道');
    } catch (e) {
      debugPrint('离开频道失败: $e');
      rethrow;
    }
  }

  // 启用/禁用本地视频
  Future<void> toggleLocalVideo() async {
    _isLocalVideoEnabled = !_isLocalVideoEnabled;
    try {
      await _engine!.enableLocalVideo(_isLocalVideoEnabled);
      debugPrint('本地视频 ${_isLocalVideoEnabled ? '已启用' : '已禁用'}');
    } catch (e) {
      debugPrint('切换本地视频状态失败: $e');
      _isLocalVideoEnabled = !_isLocalVideoEnabled; // 恢复原状态
    }
  }

  // 启用/禁用本地音频
  Future<void> toggleLocalAudio() async {
    _isLocalAudioEnabled = !_isLocalAudioEnabled;
    try {
      await _engine!.enableLocalAudio(_isLocalAudioEnabled);
      debugPrint('本地音频 ${_isLocalAudioEnabled ? '已启用' : '已禁用'}');
    } catch (e) {
      debugPrint('切换本地音频状态失败: $e');
      _isLocalAudioEnabled = !_isLocalAudioEnabled; // 恢复原状态
    }
  }

  // 设置摄像头方向
  Future<void> switchCamera() async {
    try {
      await _engine!.switchCamera();
      debugPrint('摄像头已切换');
    } catch (e) {
      debugPrint('切换摄像头失败: $e');
    }
  }

  // 获取本地用户 ID
  int? get localUid => _localUid;

  // 获取远程用户列表
  Set<int> get remoteUids => _remoteUids;

  // 获取本地视频启用状态
  bool get isLocalVideoEnabled => _isLocalVideoEnabled;

  // 获取本地音频启用状态
  bool get isLocalAudioEnabled => _isLocalAudioEnabled;

  // 获取 Agora 引擎实例
  RtcEngine? get engine => _engine;

  // 释放资源
  Future<void> dispose() async {
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;
      _localUid = null;
      _remoteUids.clear();
      debugPrint('Agora 引擎资源已释放');
    } catch (e) {
      debugPrint('释放 Agora 引擎资源失败: $e');
    }
  }
}
