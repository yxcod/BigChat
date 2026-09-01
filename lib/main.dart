import 'dart:async';

import 'package:flutter/material.dart';
import './routes/routeIndex.dart';
import './utils/storageUtil.dart';
import './utils/GlobalNavigatorKey.dart';
import './core/config/app_config.dart';
import './app/theme/app_theme.dart';
import './app/theme/app_theme_controller.dart';
import './utils/gloabl.dart';
import './utils/WebSocketManager.dart';
import './core/network/app_connection_monitor.dart';
import './features/chat/domain/chat_realtime_event.dart';
import './features/groups/presentation/group_route_registry.dart';
import './features/location/data/app_location_service.dart';
import './features/settings/application/app_notification_feedback_service.dart';
import './features/privacy/application/privacy_settings_service.dart';
import './features/privacy/presentation/privacy_unlock_page.dart';
import './features/privacy/presentation/calculator_decoy_page.dart';
import './features/groups/application/group_notification_settings_service.dart';
import './model/friendRequestModel.dart';
import './core/navigation/app_route_observer.dart';
import './features/friends/application/friendship_realtime_service.dart';
import './core/notifications/push_notification_service.dart';
import './core/permissions/initial_permission_service.dart';
import './features/calls/application/call_coordinator.dart';
import './features/account/application/session_termination_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.validate();
  await StorageUtil.init();
  await AppThemeController.instance.load();
  final hasAuthenticatedSession =
      await StorageUtil.restoreAuthenticatedSession();
  if (hasAuthenticatedSession) {
    GlobalUtil().hydrateUserInfoFromLocal();
  }
  await PrivacySettingsService.instance.load();
  await GroupNotificationSettingsService.instance.load();
  final privacySettings = PrivacySettingsService.instance.settings;

  runApp(
    MyApp(
      initialRoute: appInitialRoute(hasAuthenticatedSession),
      initiallyPrivacyLocked: appRequiresPrivacyUnlock(
        hasAuthenticatedSession: hasAuthenticatedSession,
        privacyEnabled: privacySettings.enabled,
        hasGesturePassword: privacySettings.hasGesturePassword,
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(InitialPermissionService.instance.requestOnFirstLaunch());
  });
  if (hasAuthenticatedSession) {
    unawaited(PushNotificationService.instance.initialize());
  }
}

String appInitialRoute(bool hasAuthenticatedSession) =>
    hasAuthenticatedSession ? '/mainWidget' : '/login';

bool appRequiresPrivacyUnlock({
  required bool hasAuthenticatedSession,
  required bool privacyEnabled,
  required bool hasGesturePassword,
}) => hasAuthenticatedSession && privacyEnabled && hasGesturePassword;

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.connectionMonitor,
    this.initialRoute,
    this.connectionNoticeDelay = const Duration(seconds: 2),
    this.themeController,
    this.notificationFeedbackService,
    this.initiallyPrivacyLocked = false,
    this.privacyLockRequired,
    this.privacyGestureVerifier,
  });

  final AppConnectionMonitor? connectionMonitor;
  final String? initialRoute;
  final Duration connectionNoticeDelay;
  final AppThemeController? themeController;
  final AppNotificationFeedbackService? notificationFeedbackService;
  final bool initiallyPrivacyLocked;
  final bool Function()? privacyLockRequired;
  final bool Function(List<int> pattern)? privacyGestureVerifier;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AppConnectionMonitor _connectionMonitor;
  late final AppThemeController _themeController;
  late final AppNotificationFeedbackService _notificationFeedbackService;
  AppConnectionStatus _lastConnectionStatus = AppConnectionStatus.unknown;
  AppConnectionStatus? _connectionNoticeStatus;
  late final WebSocketMessageSubscription _groupEventSubscription;
  Timer? _locationSyncTimer;
  Timer? _connectionNoticeTimer;
  Timer? _messageBannerTimer;
  OverlayEntry? _messageBannerEntry;
  bool _isAppForeground = true;
  bool _disconnectionNoticePresented = false;
  final Set<int> _handlingRemovedGroups = {};
  final Set<int> _handlingHistoryDeletedGroups = {};
  final FriendshipRealtimeService _friendshipRealtimeService =
      const FriendshipRealtimeService();
  late bool _privacyLockPending;
  bool _privacyDecoyVisible = false;
  int _privacyFailedAttempts = 0;
  bool _handlingSessionTermination = false;

  @override
  void initState() {
    super.initState();
    _privacyLockPending = widget.initiallyPrivacyLocked;
    _connectionMonitor =
        widget.connectionMonitor ?? AppConnectionMonitor.instance;
    _themeController = widget.themeController ?? AppThemeController.instance;
    _notificationFeedbackService =
        widget.notificationFeedbackService ?? AppNotificationFeedbackService();
    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
    _lastConnectionStatus = _connectionMonitor.status;
    _connectionMonitor.addListener(_handleConnectionStatusChanged);
    _groupEventSubscription = WebSocketManager().addMessageListener(
      _handleGlobalGroupEvent,
    );
    CallCoordinator.instance.initialize();
    _connectRestoredSession();
    _locationSyncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _reconcileLocationPreference(),
    );
    _reconcileLocationPreference();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.flushPendingNavigation();
    });
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
    CallCoordinator.instance.dispose();
    _locationSyncTimer?.cancel();
    _connectionNoticeTimer?.cancel();
    _messageBannerTimer?.cancel();
    _messageBannerEntry?.remove();
    super.dispose();
  }

  void _handleGlobalGroupEvent(dynamic rawMessage) {
    if (rawMessage is! Map<String, dynamic>) return;
    final terminationEvent = SessionTerminationEvent.parse(rawMessage);
    if (terminationEvent != null) {
      unawaited(_terminateReplacedSession(terminationEvent));
      return;
    }
    if (rawMessage['type'] == 'privacyMessageDestroy') {
      final rawId = rawMessage['msgId'];
      final msgId = rawId is num
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '');
      if (msgId != null) GlobalUtil().destroyPrivacyMessage(msgId);
      return;
    }
    if (rawMessage['type'] == 'privacyMessageRead') {
      final rawId = rawMessage['msgId'];
      final msgId = rawId is num
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '');
      final rawSeconds = rawMessage['destroyAfterSeconds'];
      final seconds = rawSeconds is num
          ? rawSeconds.toInt()
          : int.tryParse(rawSeconds?.toString() ?? '') ?? 10;
      if (msgId != null) {
        GlobalUtil().schedulePrivacyReadDestroy(msgId, seconds);
      }
      return;
    }
    final event = ChatRealtimeEvent.parse(rawMessage);
    if (event.type == ChatRealtimeEventType.friendRequestUpdated) {
      unawaited(_friendshipRealtimeService.handle(rawMessage));
    }
    unawaited(_handleIncomingMessageNotification(event));
    if (event.type == ChatRealtimeEventType.groupHistoryDeleted &&
        event.groupId > 0 &&
        _handlingHistoryDeletedGroups.add(event.groupId)) {
      unawaited(_handleGroupHistoryDeleted(event));
      return;
    }
    if (event.type != ChatRealtimeEventType.groupMemberRemoved ||
        event.groupId <= 0 ||
        !_handlingRemovedGroups.add(event.groupId)) {
      return;
    }
    unawaited(_handleRemovedFromGroup(event));
  }

  Future<void> _terminateReplacedSession(SessionTerminationEvent event) async {
    if (_handlingSessionTermination) return;
    _handlingSessionTermination = true;
    _dismissMessageBanner();
    WebSocketManager().disconnect();
    GlobalUtil().resetSessionState();
    await StorageUtil.logout();
    if (!mounted) return;
    final navigator = GlobalNavigatorKey.navigatorState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentNavigator = GlobalNavigatorKey.navigatorState;
      if (currentNavigator == null || !currentNavigator.mounted) return;
      showDialog<void>(
        context: currentNavigator.context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(event.title),
          content: Text(event.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _handleIncomingMessageNotification(
    ChatRealtimeEvent event,
  ) async {
    final global = GlobalUtil();
    final conversationKey = event.type == ChatRealtimeEventType.groupMessage
        ? GlobalUtil.groupConversationKey(event.groupId)
        : event.senderId;
    final conversationIsActive =
        conversationKey.isNotEmpty &&
        global.isConversationVisible(conversationKey);
    final notice = await _notificationFeedbackService.handle(
      event,
      appIsForeground: _isAppForeground,
      conversationIsActive: conversationIsActive,
    );
    if (!mounted || notice == null) return;
    _showMessageBanner(notice);
  }

  void _showMessageBanner(AppMessageNotice notice) {
    final navigator = GlobalNavigatorKey.navigatorState;
    if (navigator == null) return;
    final overlay = navigator.overlay;
    if (overlay == null) return;
    _dismissMessageBanner();
    _messageBannerEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 12,
        right: 12,
        child: SafeArea(
          bottom: false,
          child: Material(
            elevation: 8,
            color: Theme.of(context).colorScheme.surface,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                _dismissMessageBanner();
                if (notice.event.type ==
                    ChatRealtimeEventType.friendRequestUpdated) {
                  navigator.pushNamed(
                    '/friendAddManagerPage',
                    arguments: const <FriendRequestModel>[],
                  );
                } else if (notice.event.type ==
                    ChatRealtimeEventType.groupMessage) {
                  navigator.pushNamed(
                    '/groupChatDialog',
                    arguments: {
                      'groupId': notice.event.groupId,
                      'groupName': '群聊',
                    },
                  );
                } else {
                  navigator.pushNamed(
                    '/chatDialog',
                    arguments: notice.event.senderId,
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 6, 11),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0x1F07C160),
                      child: Icon(
                        Icons.notifications_rounded,
                        color: Color(0xFF07C160),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            notice.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            notice.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: _dismissMessageBanner,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_messageBannerEntry!);
    _messageBannerTimer = Timer(
      const Duration(seconds: 4),
      _dismissMessageBanner,
    );
  }

  void _dismissMessageBanner() {
    _messageBannerTimer?.cancel();
    _messageBannerTimer = null;
    _messageBannerEntry?.remove();
    _messageBannerEntry = null;
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
        ScaffoldMessenger.maybeOf(navigator.context)?.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _handlingRemovedGroups.remove(groupId);
    });
  }

  Future<void> _handleGroupHistoryDeleted(ChatRealtimeEvent event) async {
    final groupId = event.groupId;
    await GlobalUtil().deleteChatRecords(
      GlobalUtil.groupConversationKey(groupId),
    );
    if (!mounted) {
      _handlingHistoryDeletedGroups.remove(groupId);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navigator = GlobalNavigatorKey.navigatorState;
      if (navigator == null || !navigator.mounted) {
        _handlingHistoryDeletedGroups.remove(groupId);
        return;
      }
      final message =
          event.data['message']?.toString() ?? '群主或管理员已删除当前群聊的全部聊天记录';
      if (GroupRouteRegistry.isActive(groupId)) {
        await showDialog<void>(
          context: navigator.context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('群聊通知'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
        if (navigator.mounted) {
          navigator.pushNamedAndRemoveUntil('/mainWidget', (_) => false);
        }
      } else {
        ScaffoldMessenger.maybeOf(navigator.context)?.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _handlingHistoryDeletedGroups.remove(groupId);
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
        GlobalUtil().setAppForeground(true);
        _connectionMonitor.setAppActive(true);
        WebSocketManager().reconnectNow();
        _reconcileLocationPreference();
        unawaited(PushNotificationService.instance.updateAppForeground(true));
        if (_privacyLockPending && mounted) {
          // 根节点锁屏必须参与当前帧构建，不能先展示主界面再跳转锁屏页。
          setState(() {});
        }
        break;
    }
  }

  void _enterBackground() {
    _isAppForeground = false;
    GlobalUtil().setAppForeground(false);
    _dismissMessageBanner();
    _connectionMonitor.setAppActive(false);
    unawaited(PushNotificationService.instance.updateAppForeground(false));
    _connectionNoticeTimer?.cancel();
    _connectionNoticeTimer = null;
    _disconnectionNoticePresented = false;
    var privacyGateChanged = false;
    if (_requiresPrivacyGate()) {
      privacyGateChanged = !_privacyLockPending || _privacyDecoyVisible;
      _privacyLockPending = true;
      _privacyDecoyVisible = false;
    }
    if (_connectionNoticeStatus != null && mounted) {
      setState(() => _connectionNoticeStatus = null);
    } else if (privacyGateChanged && mounted) {
      // 在应用真正进入后台前绘制隐私锁，保证系统保留的最后一帧不是业务界面。
      setState(() {});
    }
  }

  bool _requiresPrivacyGate() {
    final override = widget.privacyLockRequired;
    if (override != null) return override();
    final privacy = PrivacySettingsService.instance.settings;
    return privacy.enabled &&
        privacy.hasGesturePassword &&
        (GlobalUtil().userName ?? '').isNotEmpty;
  }

  Future<void> _completePrivacyUnlock() async {
    if (!mounted) return;
    setState(() {
      _privacyLockPending = false;
      _privacyDecoyVisible = false;
      _privacyFailedAttempts = 0;
    });
  }

  Future<void> _rejectPrivacyUnlock() async {
    _privacyFailedAttempts++;
    if (_privacyFailedAttempts >= 3) {
      await _forcePrivacyLogout();
      return;
    }
    if (!mounted) return;
    setState(() => _privacyDecoyVisible = true);
  }

  Future<void> _forcePrivacyLogout() async {
    if (mounted) {
      setState(() {
        _privacyLockPending = false;
        _privacyDecoyVisible = false;
        _privacyFailedAttempts = 0;
      });
    } else {
      _privacyLockPending = false;
      _privacyDecoyVisible = false;
      _privacyFailedAttempts = 0;
    }
    await PushNotificationService.instance.unregisterCurrentUser();
    WebSocketManager().disconnect();
    GlobalUtil().resetSessionState();
    await StorageUtil.logout();
    final navigator = GlobalNavigatorKey.navigatorState;
    if (navigator != null) {
      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  void _reconcileLocationPreference() {
    if ((GlobalUtil().userName ?? '').isEmpty) return;
    unawaited(
      AppLocationService().reconcileServerPreference().catchError((_) {}),
    );
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
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) => MaterialApp(
        title: "全信",
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeController.themeMode,
        navigatorKey: GlobalNavigatorKey.navigatorKey,
        navigatorObservers: [appRouteObserver],
        initialRoute:
            widget.initialRoute ??
            appInitialRoute(
              (GlobalUtil().userName ?? '').isNotEmpty &&
                  (GlobalUtil().token ?? '').isNotEmpty,
            ),
        routes: getRoutes(),
        onGenerateRoute: generateRoute,
        builder: (context, child) => Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => SelectionArea(
                child: Stack(
                  children: [
                    if (child != null)
                      Positioned.fill(
                        child: TickerMode(
                          enabled: !_privacyLockPending,
                          child: Offstage(
                            offstage: _privacyLockPending,
                            child: child,
                          ),
                        ),
                      ),
                    if (_connectionNoticeStatus != null)
                      _buildConnectionNotice(),
                    if (_privacyLockPending)
                      Positioned.fill(
                        child: _privacyDecoyVisible
                            ? const CalculatorDecoyPage()
                            : PrivacyUnlockPage(
                                onUnlocked: _completePrivacyUnlock,
                                onRejected: _rejectPrivacyUnlock,
                                verifyGesture: widget.privacyGestureVerifier,
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
