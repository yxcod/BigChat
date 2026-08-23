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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await StorageUtil.init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.connectionMonitor});

  final AppConnectionMonitor? connectionMonitor;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppConnectionMonitor _connectionMonitor;
  AppConnectionStatus _lastConnectionStatus = AppConnectionStatus.unknown;
  AppConnectionStatus? _connectionNoticeStatus;

  @override
  void initState() {
    super.initState();
    _connectionMonitor =
        widget.connectionMonitor ?? AppConnectionMonitor.instance;
    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
    _lastConnectionStatus = _connectionMonitor.status;
    _connectionMonitor.addListener(_handleConnectionStatusChanged);
  }

  @override
  void dispose() {
    // 移除应用生命周期监听
    WidgetsBinding.instance.removeObserver(this);
    _connectionMonitor.removeListener(_handleConnectionStatusChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 监听多个可能表示应用即将关闭的状态
    switch (state) {
      case AppLifecycleState.paused:
        // 应用进入后台
        debugPrint('应用进入后台');
        unawaited(GlobalUtil().flushChatRecordsToLocal());
        break;
      case AppLifecycleState.inactive:
        // 应用变为非活动状态
        debugPrint('应用变为非活动状态');
        break;
      case AppLifecycleState.detached:
        // 应用即将被销毁
        debugPrint('应用即将被销毁');

        break;
      case AppLifecycleState.resumed:
        unawaited(_connectionMonitor.checkNow());
        WebSocketManager().reconnectNow();
        break;
      default:
        break;
    }
  }

  void _handleConnectionStatusChanged() {
    final currentStatus = _connectionMonitor.status;
    final previousStatus = _lastConnectionStatus;
    if (currentStatus == previousStatus) {
      return;
    }
    _lastConnectionStatus = currentStatus;

    if (currentStatus == AppConnectionStatus.disconnected) {
      if (mounted) {
        setState(() {
          _connectionNoticeStatus = AppConnectionStatus.disconnected;
        });
      }
    } else if (currentStatus == AppConnectionStatus.connected &&
        previousStatus == AppConnectionStatus.disconnected) {
      if (mounted) {
        setState(() {
          _connectionNoticeStatus = AppConnectionStatus.connected;
        });
      }
    }
  }

  void _dismissConnectionNotice() {
    if (mounted) {
      setState(() => _connectionNoticeStatus = null);
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
      initialRoute: '/login',
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
