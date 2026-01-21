import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../pages/videoCallInviteWaitingPage.dart';
import 'Gloabl.dart';
import 'GlobalNavigatorKey.dart';

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;

  WebSocketManager._internal();

  String? _url;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  WebSocketStatus get status => _status;
  Function(WebSocketStatus)? _onStatusChanged;
  List<Function(dynamic)> _onMessageReceivedListeners = [];
  Function(Object)? _onError;

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  int _maxReconnectAttempts = 50;
  Duration _reconnectDelay = const Duration(seconds: 2);
  Duration _heartbeatInterval = const Duration(seconds: 15);

  bool get isConnected => _status == WebSocketStatus.connected;

  /// 初始化WebSocket连接或更新回调函数
  Future<void> connect(
    String url, {
    Function(WebSocketStatus)? onStatusChanged,
    Function(dynamic)? onMessageReceived,
    Function(Object)? onError,
    Duration? heartbeatInterval,
    int? maxReconnectAttempts,
    Duration? reconnectDelay,
  }) async {
    _url = url;
    _onStatusChanged = onStatusChanged;
    if (onMessageReceived != null) {
      _onMessageReceivedListeners.add(onMessageReceived);
    }
    _onError = onError;

    if (heartbeatInterval != null) _heartbeatInterval = heartbeatInterval;
    if (maxReconnectAttempts != null)
      _maxReconnectAttempts = maxReconnectAttempts;
    if (reconnectDelay != null) _reconnectDelay = reconnectDelay;

    await _connect();
  }

  /// 设置消息监听器
  void setMessageListener(Function(dynamic)? onMessageReceived) {
    if (onMessageReceived != null) {
      _onMessageReceivedListeners.add(onMessageReceived);
    }
  }

  /// 移除消息监听器
  void removeMessageListener(Function(dynamic) onMessageReceived) {
    _onMessageReceivedListeners.remove(onMessageReceived);
  }

  /// 清空所有消息监听器
  void clearMessageListeners() {
    _onMessageReceivedListeners.clear();
  }

  /// 内部连接方法
  Future<void> _connect() async {
    if (_status == WebSocketStatus.connecting ||
        _status == WebSocketStatus.connected) {
      return;
    }

    _setStatus(WebSocketStatus.connecting);

    try {
      _socket = await WebSocket.connect(_url!);
      _reconnectAttempts = 0;
      _setStatus(WebSocketStatus.connected);

      // 监听消息
      _socket!.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: true,
      );

      // 连接成功后立即发送一条心跳
      _sendHeartbeat();

      // 启动心跳检测
      _startHeartbeat();
    } catch (e) {
      _handleError(e);
    }
  }

  /// 发送消息
  void send(dynamic message) {
    if (!isConnected) {
      if (kDebugMode) {
        print('WebSocket is not connected');
      }
      return;
    }

    try {
      if (message is String) {
        _socket!.add(message);
      } else {
        _socket!.add(json.encode(message));
      }
    } catch (e) {
      _handleError(e);
    }
  }

  /// 发送心跳包
  void _sendHeartbeat() {
    try {
      if (isConnected) {
        // 添加userName到心跳包中
        _socket!.add(
          json.encode({
            'type': 'ping',
            'userName': GlobalUtil().userName ?? '',
          }),
        );
      }
    } catch (e) {
      _handleError(e);
    }
  }

  /// 启动心跳检测
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      _sendHeartbeat();
    });
  }

  /// 停止心跳检测
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// 处理接收到的消息
  void _handleMessage(dynamic message) {
    try {
      dynamic data = message;
      if (message is String) {
        data = json.decode(message);
      }

      // 处理视频通话邀请
      if (data is Map<String, dynamic>) {
        final messageType = data['type'] ?? '';
        if (messageType == 'videoCallInvite') {
          final senderName = data['sender'] ?? '';
          final channelName = data['channelName'] ?? '';
          final token = data['token'] ?? '';

          // 从本地好友列表中获取nickName
          final globalUtil = GlobalUtil();
          final friendInfo = globalUtil.getFriendInfoByUserName(senderName);
          final displayName = friendInfo.nickName ?? senderName;

          if (displayName.isNotEmpty && channelName.isNotEmpty) {
            // 使用全局NavigatorKey显示视频邀请页面
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                final navigatorState = GlobalNavigatorKey.navigatorState;
                if (navigatorState != null) {
                  navigatorState.push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (context) => VideoCallInviteWaitingPage(
                        inviterName: displayName,
                        inviterUsername: senderName,
                        channelName: channelName,
                        token: token,
                      ),
                    ),
                  );
                } else {
                  if (kDebugMode) {
                    print('导航器状态为空，无法显示视频邀请');
                  }
                }
              } catch (e) {
                if (kDebugMode) {
                  print('显示视频邀请失败: $e');
                }
              }
            });
          }
        }
      }

      // 调用所有消息监听器
      for (final listener in _onMessageReceivedListeners) {
        try {
          listener(data);
        } catch (e) {
          if (kDebugMode) {
            print('消息监听器执行错误: $e');
          }
        }
      }
    } catch (e) {
      _handleError(e);
    }
  }

  /// 处理错误
  void _handleError(Object error) {
    if (kDebugMode) {
      print('WebSocket error: $error');
    }

    _setStatus(WebSocketStatus.error);
    _onError?.call(error);
    _attemptReconnect();
  }

  /// 处理连接关闭
  void _handleDone() {
    if (kDebugMode) {
      print('WebSocket connection closed');
    }

    _setStatus(WebSocketStatus.disconnected);
    _attemptReconnect();
  }

  /// 尝试重连
  void _attemptReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print('Max reconnect attempts reached');
      }
      return;
    }

    _stopReconnectTimer();
    _setStatus(WebSocketStatus.reconnecting);

    _reconnectTimer = Timer(_reconnectDelay * (_reconnectAttempts + 1), () {
      _reconnectAttempts++;
      if (kDebugMode) {
        print(
          'Attempting to reconnect ($_reconnectAttempts/$_maxReconnectAttempts)...',
        );
      }
      _connect();
    });
  }

  /// 停止重连计时器
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 断开连接
  void disconnect() {
    _stopHeartbeat();
    _stopReconnectTimer();
    _socket?.close();
    _socket = null;
    _setStatus(WebSocketStatus.disconnected);
  }

  /// 重置WebSocket
  void reset() {
    disconnect();
    _url = null;
    _onStatusChanged = null;
    _onError = null;
    _reconnectAttempts = 0;
  }

  /// 更新连接状态
  void _setStatus(WebSocketStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _onStatusChanged?.call(newStatus);
    }
  }
}
