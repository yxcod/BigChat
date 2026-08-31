import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/network/app_connection_monitor.dart';
import 'gloabl.dart';

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

typedef WebSocketMessageListener = void Function(dynamic message);
typedef WebSocketStatusListener = void Function(WebSocketStatus status);
typedef WebSocketErrorListener = void Function(Object error);

class WebSocketMessageSubscription {
  WebSocketMessageSubscription._(this._manager, this._listener);

  final WebSocketManager _manager;
  WebSocketMessageListener? _listener;

  void cancel() {
    final listener = _listener;
    if (listener == null) {
      return;
    }
    _manager.removeMessageListener(listener);
    _listener = null;
  }
}

class WebSocketStatusSubscription {
  WebSocketStatusSubscription._(this._manager, this._listener);

  final WebSocketManager _manager;
  WebSocketStatusListener? _listener;

  void cancel() {
    final listener = _listener;
    if (listener == null) {
      return;
    }
    _manager.removeStatusListener(listener);
    _listener = null;
  }
}

class WebSocketErrorSubscription {
  WebSocketErrorSubscription._(this._manager, this._listener);

  final WebSocketManager _manager;
  WebSocketErrorListener? _listener;

  void cancel() {
    final listener = _listener;
    if (listener == null) {
      return;
    }
    _manager.removeErrorListener(listener);
    _listener = null;
  }
}

class WebSocketManager {
  static final WebSocketManager _instance = WebSocketManager._internal();
  factory WebSocketManager() => _instance;

  WebSocketManager._internal() {
    AppConnectionMonitor.instance.addBackendReachableListener(reconnectNow);
  }

  String? _url;
  WebSocketStatus _status = WebSocketStatus.disconnected;
  WebSocketStatus get status => _status;
  final Set<WebSocketStatusListener> _statusListeners = {};
  final Set<WebSocketMessageListener> _onMessageReceivedListeners = {};
  final Set<WebSocketErrorListener> _errorListeners = {};

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  int? _maxReconnectAttempts;
  Duration _reconnectDelay = const Duration(seconds: 2);
  Duration _heartbeatInterval = const Duration(seconds: 15);
  bool _shouldReconnect = true;

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
    _shouldReconnect = true;
    _url = url;
    AppConnectionMonitor.instance.expectRealtimeConnection(true);
    if (onStatusChanged != null) {
      _statusListeners.add(onStatusChanged);
    }
    if (onMessageReceived != null) {
      _onMessageReceivedListeners.add(onMessageReceived);
    }
    if (onError != null) {
      _errorListeners.add(onError);
    }

    if (heartbeatInterval != null) _heartbeatInterval = heartbeatInterval;
    if (maxReconnectAttempts != null) {
      _maxReconnectAttempts = maxReconnectAttempts;
    }
    if (reconnectDelay != null) _reconnectDelay = reconnectDelay;

    await _connect();
  }

  /// 添加独立的消息订阅。页面销毁时必须调用返回对象的 cancel。
  WebSocketMessageSubscription addMessageListener(
    WebSocketMessageListener listener,
  ) {
    _onMessageReceivedListeners.add(listener);
    return WebSocketMessageSubscription._(this, listener);
  }

  WebSocketStatusSubscription addStatusListener(
    WebSocketStatusListener listener,
  ) {
    _statusListeners.add(listener);
    return WebSocketStatusSubscription._(this, listener);
  }

  WebSocketErrorSubscription addErrorListener(WebSocketErrorListener listener) {
    _errorListeners.add(listener);
    return WebSocketErrorSubscription._(this, listener);
  }

  /// 移除消息监听器
  void removeMessageListener(WebSocketMessageListener onMessageReceived) {
    _onMessageReceivedListeners.remove(onMessageReceived);
  }

  /// 清空所有消息监听器
  void clearMessageListeners() {
    _onMessageReceivedListeners.clear();
  }

  void removeStatusListener(WebSocketStatusListener listener) {
    _statusListeners.remove(listener);
  }

  void removeErrorListener(WebSocketErrorListener listener) {
    _errorListeners.remove(listener);
  }

  /// 内部连接方法
  Future<void> _connect() async {
    if (_status == WebSocketStatus.connecting ||
        _status == WebSocketStatus.connected) {
      return;
    }

    _setStatus(WebSocketStatus.connecting);

    try {
      final token = GlobalUtil().token?.trim() ?? '';
      _socket = await WebSocket.connect(
        _url!,
        headers: token.isEmpty
            ? null
            : <String, dynamic>{'Authorization': 'Bearer $token'},
      );
      _reconnectAttempts = 0;
      _setStatus(WebSocketStatus.connected);
      AppConnectionMonitor.instance.reportRealtimeConnected();

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
  bool send(dynamic message) {
    if (!isConnected) {
      if (kDebugMode) {
        print('WebSocket is not connected');
      }
      return false;
    }

    try {
      if (message is String) {
        _socket!.add(message);
      } else {
        _socket!.add(json.encode(message));
      }
      return true;
    } catch (e) {
      _handleError(e);
      return false;
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

      // 调用所有消息监听器
      for (final listener in List.of(_onMessageReceivedListeners)) {
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
    if (_shouldReconnect) {
      AppConnectionMonitor.instance.reportRealtimeUnavailable();
    }
    for (final listener in List.of(_errorListeners)) {
      listener(error);
    }
    if (_shouldReconnect) {
      _attemptReconnect();
    }
  }

  /// 处理连接关闭
  void _handleDone() {
    if (kDebugMode) {
      print('WebSocket connection closed');
    }

    _setStatus(WebSocketStatus.disconnected);
    if (_shouldReconnect) {
      AppConnectionMonitor.instance.reportRealtimeUnavailable();
      _attemptReconnect();
    }
  }

  /// 尝试重连
  void _attemptReconnect() {
    if (!_shouldReconnect || _reconnectTimer?.isActive == true) {
      return;
    }
    if (_maxReconnectAttempts != null &&
        _reconnectAttempts >= _maxReconnectAttempts!) {
      if (kDebugMode) {
        print('Max reconnect attempts reached');
      }
      return;
    }

    _stopReconnectTimer();
    _setStatus(WebSocketStatus.reconnecting);

    final delay = reconnectDelayForAttempt(
      _reconnectAttempts,
      baseDelay: _reconnectDelay,
    );
    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      if (kDebugMode) {
        print(
          'Attempting to reconnect ($_reconnectAttempts/${_maxReconnectAttempts ?? 'unlimited'})...',
        );
      }
      _connect();
    });
  }

  @visibleForTesting
  static Duration reconnectDelayForAttempt(
    int attempt, {
    Duration baseDelay = const Duration(seconds: 2),
    Duration maximumDelay = const Duration(seconds: 30),
  }) {
    final exponent = attempt.clamp(0, 10);
    final milliseconds = baseDelay.inMilliseconds * (1 << exponent);
    return Duration(
      milliseconds: milliseconds.clamp(0, maximumDelay.inMilliseconds),
    );
  }

  void reconnectNow() {
    if (!_shouldReconnect ||
        _url == null ||
        _status == WebSocketStatus.connected ||
        _status == WebSocketStatus.connecting) {
      return;
    }
    _stopReconnectTimer();
    unawaited(_connect());
  }

  /// 停止重连计时器
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// 断开连接
  void disconnect() {
    _shouldReconnect = false;
    _stopHeartbeat();
    _stopReconnectTimer();
    _socket?.close();
    _socket = null;
    _setStatus(WebSocketStatus.disconnected);
    AppConnectionMonitor.instance.expectRealtimeConnection(false);
  }

  /// 重置WebSocket
  void reset() {
    disconnect();
    clearMessageListeners();
    _statusListeners.clear();
    _errorListeners.clear();
    _url = null;
    _reconnectAttempts = 0;
    _maxReconnectAttempts = null;
    _reconnectDelay = const Duration(seconds: 2);
    _heartbeatInterval = const Duration(seconds: 15);
  }

  /// 更新连接状态
  void _setStatus(WebSocketStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      for (final listener in List.of(_statusListeners)) {
        listener(newStatus);
      }
    }
  }
}
