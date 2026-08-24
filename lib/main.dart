import 'dart:async';

import 'package:flutter/material.dart';
import './routes/routeIndex.dart';
import './utils/storageUtil.dart';
import './utils/GlobalNavigatorKey.dart';
import './core/config/app_config.dart';
import './app/theme/app_theme.dart';
import './utils/gloabl.dart';
import './utils/WebSocketManager.dart';
import './core/network/app_connection_monitor.dart';
import './features/chat/domain/chat_realtime_event.dart';
import './features/groups/presentation/group_route_registry.dart';
import './features/location/data/app_location_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await StorageUtil.init();
  final hasAuthenticatedSession =
      await StorageUtil.restoreAuthenticatedSession();

  runApp(MyApp(initialRoute: appInitialRoute(hasAuthenticatedSession)));
}

String appInitialRoute(bool hasAuthenticatedSession) =>
    hasAuthenticatedSession ? '/mainWidget' : '/login';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.connectionMonitor,
    this.initialRoute,
    this.connectionNoticeDelay = const Duration(seconds: 2),
  });

  final AppConnectionMonitor? connectionMonitor;
  final String? initialRoute;
  final Duration connectionNoticeDelay;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppConnectionMonitor _connectionMonitor;
  AppConnectionStatus _lastConnectionStatus = AppConnectionStatus.unknown;
  AppConnectionStatus? _connectionNoticeStatus;
  late final WebSocketMessageSubscription _groupEventSubscription;
  Timer? _locationSyncTimer;
  Timer? _connectionNoticeTimer;
  bool _isAppForeground = true;
  bool _disconnectionNoticePresented = false;
  final Set<int> _handlingRemovedGroups = {};

  @override
  void initState() {
    super.initState();
    _connectionMonitor =
        widget.connectionMonitor ?? AppConnectionMonitor.instance;
    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
    _lastConnectionStatus = _connectionMonitor.status;
    _connectionMonitor.addListener(_handleConnectionStatusChanged);
    _groupEventSubscription = WebSocketManager().addMessageListener(
      _handleGlobalGroupEvent,
    );
    _connectRestoredSession();
    _locationSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _syncLocationIfPermitted(),
    );
    _syncLocationIfPermitted();
  }

  void _connectRestoredSession() {
    final global = GlobalUtil();
    final userName = global.userName?.trim() ?? '';
    final token = global.token?.trim() ?? '';
    if (userName.isEmpty || token.isEmpty) return;
    unawaited(
      WebSocketManager()
          .connect(global.getChatWebSocketURL(userName))
          .catchError((Object error) {
            debugPrint('恢复登录后的 WebSocket 连接失败：$error');
          }),
    );
  }

  @override
  void dispose() {
    // 移除应用生命周期监听
    WidgetsBinding.instance.removeObserver(this);
    _connectionMonitor.removeListener(_handleConnectionStatusChanged);
    _groupEventSubscription.cancel();
    _locationSyncTimer?.cancel();
    _connectionNoticeTimer?.cancel();
    super.dispose();
  }

  void _handleGlobalGroupEvent(dynamic rawMessage) {
    if (rawMessage is! Map<String, dynamic>) return;
    final event = ChatRealtimeEvent.parse(rawMessage);
    if (event.type != ChatRealtimeEventType.groupMemberRemoved ||
        event.groupId <= 0 ||
        !_handlingRemovedGroups.add(event.groupId)) {
      return;
    }
    unawaited(_handleRemovedFromGroup(event));
  }

  Future<void> _handleRemovedFromGroup(ChatRealtimeEvent event) async {
    final groupId = event.groupId;
    await GlobalUtil().deleteChatRecords(
      GlobalUtil.groupConversationKey(groupId),
    );
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = GlobalNavigatorKey.navigatorState;
      if (navigator == null) {
        _handlingRemovedGroups.remove(groupId);
        return;
      }
      final message = event.data['message']?.toString() ?? '您已被移出该群聊';
      if (GroupRouteRegistry.isActive(groupId)) {
        navigator.pushNamedAndRemoveUntil(
          '/mainWidget',
          (route) => false,
          arguments: {
            'isRemovedFromGroup': true,
            'removedGroupId': groupId,
            'message': message,
          },
        );
      } else {
        ScaffoldMessenger.maybeOf(
          navigator.context,
        )?.showSnackBar(SnackBar(content: Text(message)));
      }
      _handlingRemovedGroups.remove(groupId);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 监听多个可能表示应用即将关闭的状态
    switch (state) {
      case AppLifecycleState.paused:
        // 应用进入后台
        debugPrint('应用进入后台');
        _enterBackground();
        unawaited(GlobalUtil().flushChatRecordsToLocal());
        break;
      case AppLifecycleState.inactive:
        // 应用变为非活动状态
        debugPrint('应用变为非活动状态');
        _enterBackground();
        break;
      case AppLifecycleState.hidden:
        _enterBackground();
        break;
      case AppLifecycleState.detached:
        // 应用即将被销毁
        debugPrint('应用即将被销毁');
        _enterBackground();
        break;
      case AppLifecycleState.resumed:
        _isAppForeground = true;
        _connectionMonitor.setAppActive(true);
        WebSocketManager().reconnectNow();
        _syncLocationIfPermitted();
        break;
    }
  }

  void _enterBackground() {
    _isAppForeground = false;
    _connectionMonitor.setAppActive(false);
    _connectionNoticeTimer?.cancel();
    _connectionNoticeTimer = null;
    _disconnectionNoticePresented = false;
    if (_connectionNoticeStatus != null && mounted) {
      setState(() => _connectionNoticeStatus = null);
    }
  }

  void _syncLocationIfPermitted() {
    if ((GlobalUtil().userName ?? '').isEmpty) return;
    unawaited(AppLocationService().syncIfPermitted().catchError((_) {}));
  }

  void _handleConnectionStatusChanged() {
    final currentStatus = _connectionMonitor.status;
    final previousStatus = _lastConnectionStatus;
    if (currentStatus == previousStatus) {
      return;
    }
    _lastConnectionStatus = currentStatus;

    if (currentStatus == AppConnectionStatus.disconnected) {
      if (!_isAppForeground) return;
      _connectionNoticeTimer?.cancel();
      _connectionNoticeTimer = Timer(widget.connectionNoticeDelay, () {
        if (!mounted ||
            !_isAppForeground ||
            _connectionMonitor.status != AppConnectionStatus.disconnected) {
          return;
        }
        setState(() {
          _disconnectionNoticePresented = true;
          _connectionNoticeStatus = AppConnectionStatus.disconnected;
        });
      });
    } else if (currentStatus == AppConnectionStatus.connected &&
        previousStatus == AppConnectionStatus.disconnected) {
      _connectionNoticeTimer?.cancel();
      _connectionNoticeTimer = null;
      if (mounted && _isAppForeground && _disconnectionNoticePresented) {
        setState(() {
          _connectionNoticeStatus = AppConnectionStatus.connected;
        });
      }
    }
  }

  void _dismissConnectionNotice() {
    if (mounted) {
      setState(() {
        if (_connectionNoticeStatus == AppConnectionStatus.connected) {
          _disconnectionNoticePresented = false;
        }
        _connectionNoticeStatus = null;
      });
    }
  }

  Widget _buildConnectionNotice() {
    final disconnected =
        _connectionNoticeStatus == AppConnectionStatus.disconnected;
    return Positioned.fill(
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: true,
            onDismiss: _dismissConnectionNotice,
            color: Colors.black54,
          ),
          Center(
            child: AlertDialog(
              title: Text(disconnected ? '连接已断开' : '连接已恢复'),
              content: Text(
                disconnected ? '当前无法连接网络或后端服务器，应用正在自动重连。' : '网络和服务器连接已恢复。',
              ),
              actions: [
                TextButton(
                  onPressed: _dismissConnectionNotice,
                  child: const Text('知道了'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "全信",
      theme: AppTheme.light,
      navigatorKey: GlobalNavigatorKey.navigatorKey,
      initialRoute:
          widget.initialRoute ??
          appInitialRoute(
            (GlobalUtil().userName ?? '').isNotEmpty &&
                (GlobalUtil().token ?? '').isNotEmpty,
          ),
      routes: getRoutes(),
      onGenerateRoute: generateRoute,
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          if (_connectionNoticeStatus != null) _buildConnectionNotice(),
        ],
      ),
    );
  }
}
