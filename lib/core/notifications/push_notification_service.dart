import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jpush_flutter/jpush_flutter.dart';
import 'package:jpush_flutter/jpush_interface.dart';

import '../../features/settings/data/app_settings_repository.dart';
import '../../utils/GlobalNavigatorKey.dart';
import '../../utils/gloabl.dart';
import '../../utils/http.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static const _androidAppKey = 'cd7d150d0ea4eea421b58559';

  JPushFlutterInterface? _jpush;
  String _registrationId = '';
  Map<String, dynamic>? _pendingOpen;
  bool _initialized = false;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<void> initialize() async {
    if (!isSupported) return;
    if (_initialized) {
      await syncAuthenticatedSession(appForeground: true);
      return;
    }
    _initialized = true;
    final jpush = JPush.newJPush();
    _jpush = jpush;
    jpush.addEventHandler(
      onReceiveNotification: (_) async {},
      onReceiveMessage: (_) async {},
      onOpenNotification: (event) async => _openNotification(event),
      onConnected: (_) async {
        await syncAuthenticatedSession(appForeground: true);
      },
      onReceiveNotificationAuthorization: (_) async {},
      onNotifyMessageUnShow: (_) async {},
      onInAppMessageClick: (_) async {},
      onInAppMessageShow: (_) async {},
      onNotifyButtonClick: (_) async {},
      onCommandResult: (_) async {},
      onReceiveDeviceToken: (_) async {},
      onVoipMessage: (_) async {},
    );
    // 只在已有有效登录会话后调用；此时用户已经同意内部用户协议。
    jpush.setAuth(enable: true);
    jpush.setup(
      appKey: _androidAppKey,
      channel: 'developer-default',
      production: true,
      debug: !kReleaseMode,
    );
    jpush.requestRequiredPermission();
    await syncAuthenticatedSession(appForeground: true);
  }

  Future<void> syncAuthenticatedSession({required bool appForeground}) async {
    if (!isSupported) return;
    final userName = GlobalUtil().userName?.trim() ?? '';
    if (userName.isEmpty) return;
    final registrationId = await _resolveRegistrationId();
    if (registrationId.isEmpty) return;
    final settings = await AppSettingsRepository(ownerId: userName).load();
    try {
      await HttpUtil().post(
        '/api/push/register',
        data: {
          'userName': userName,
          'registrationId': registrationId,
          'platform': 'android',
          'deviceId': registrationId,
          'appForeground': appForeground,
          'bannerEnabled': settings.bannerEnabled,
          'soundEnabled': settings.messageSoundEnabled,
          'vibrationEnabled': settings.vibrationEnabled,
        },
      );
    } catch (error) {
      debugPrint('推送设备注册失败：$error');
    }
  }

  Future<void> updateAppForeground(bool foreground) async {
    if (!isSupported) return;
    final userName = GlobalUtil().userName?.trim() ?? '';
    final registrationId = await _resolveRegistrationId();
    if (userName.isEmpty || registrationId.isEmpty) return;
    try {
      await HttpUtil().post(
        '/api/push/appState',
        data: {
          'userName': userName,
          'registrationId': registrationId,
          'appForeground': foreground,
        },
      );
    } catch (error) {
      debugPrint('推送前后台状态同步失败：$error');
    }
  }

  Future<void> unregisterCurrentUser() async {
    if (!isSupported) return;
    final userName = GlobalUtil().userName?.trim() ?? '';
    final registrationId = await _resolveRegistrationId();
    if (userName.isEmpty || registrationId.isEmpty) return;
    try {
      await HttpUtil().post(
        '/api/push/unregister',
        data: {'userName': userName, 'registrationId': registrationId},
      );
    } catch (error) {
      debugPrint('推送设备注销失败：$error');
    }
  }

  Future<String> _resolveRegistrationId() async {
    if (_registrationId.isNotEmpty) return _registrationId;
    try {
      _registrationId = (await _jpush?.getRegistrationID() ?? '').trim();
    } catch (error) {
      debugPrint('获取极光 Registration ID 失败：$error');
    }
    return _registrationId;
  }

  Future<void> _openNotification(Map<String, dynamic> event) async {
    final extras = _extractExtras(event);
    if (extras.isEmpty) return;
    final navigator = GlobalNavigatorKey.navigatorState;
    if (navigator == null) {
      _pendingOpen = extras;
      return;
    }
    _navigate(navigator, extras);
  }

  void flushPendingNavigation() {
    final extras = _pendingOpen;
    final navigator = GlobalNavigatorKey.navigatorState;
    if (extras == null || navigator == null) return;
    _pendingOpen = null;
    _navigate(navigator, extras);
  }

  Map<String, dynamic> _extractExtras(Map<String, dynamic> event) {
    final raw = event['extras'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return event;
  }

  void _navigate(NavigatorState navigator, Map<String, dynamic> extras) {
    final eventType = extras['eventType']?.toString() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (eventType == 'friendRequest' || eventType == 'friendRequestUpdated') {
        navigator.pushNamed('/friendAddManagerPage', arguments: const []);
      } else if (eventType == 'groupMessage') {
        final groupId = int.tryParse(extras['groupId']?.toString() ?? '');
        if (groupId != null && groupId > 0) {
          navigator.pushNamed(
            '/groupChatDialog',
            arguments: {'groupId': groupId, 'groupName': '群聊'},
          );
        }
      } else if (eventType == 'privateMessage') {
        final senderId = extras['senderId']?.toString() ?? '';
        if (senderId.isNotEmpty) {
          navigator.pushNamed('/chatDialog', arguments: senderId);
        }
      }
    });
  }
}
