import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../pages/videoCallInviteWaitingPage.dart';
import '../../../pages/videoCallPage.dart';
import '../../../utils/GlobalNavigatorKey.dart';
import '../../../utils/WebSocketManager.dart';
import '../../../utils/gloabl.dart';
import '../domain/call_signal.dart';

class CallCoordinator {
  CallCoordinator._();

  static final CallCoordinator instance = CallCoordinator._();

  final ValueNotifier<AppCallSession?> activeSession =
      ValueNotifier<AppCallSession?>(null);
  WebSocketMessageSubscription? _subscription;
  Timer? _ringTimeout;
  bool _initialized = false;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _subscription = WebSocketManager().addMessageListener(_handleMessage);
  }

  void handleExternalInvite(Map<String, dynamic> extras) {
    initialize();
    final eventType = extras['eventType']?.toString() ?? '';
    if (eventType != 'videoCallInvite' && eventType != 'groupVideoCallInvite') {
      return;
    }
    _handleMessage({
      ...extras,
      'type': 'callSignal',
      'action': 'invite',
      'callKind': eventType == 'groupVideoCallInvite' ? 'group' : 'private',
      'sender': extras['senderId'],
      'senderName': extras['senderName'],
      'receiver': _currentUser,
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _ringTimeout?.cancel();
    _initialized = false;
  }

  Future<bool> startPrivateCall({
    required String peerId,
    required String peerName,
  }) async {
    final receiver = peerId.trim();
    if (receiver.isEmpty || !_canStartCall()) return false;
    final signal = _newSignal(
      kind: AppCallKind.private,
      receiverId: receiver,
      title: peerName.trim().isEmpty ? receiver : peerName.trim(),
    );
    activeSession.value = AppCallSession(
      signal: signal,
      phase: AppCallPhase.outgoingRinging,
      isCaller: true,
    );
    if (!_send(signal)) {
      activeSession.value = null;
      return false;
    }
    _startRingTimeout();
    _openLobby();
    return true;
  }

  Future<bool> startGroupCall({
    required int groupId,
    required String groupName,
  }) async {
    if (groupId <= 0 || !_canStartCall()) return false;
    final signal = _newSignal(
      kind: AppCallKind.group,
      groupId: groupId,
      title: groupName.trim().isEmpty ? '群聊' : groupName.trim(),
    );
    activeSession.value = AppCallSession(
      signal: signal,
      phase: AppCallPhase.outgoingRinging,
      isCaller: true,
    );
    if (!_send(signal)) {
      activeSession.value = null;
      return false;
    }
    _startRingTimeout();
    _openLobby();
    return true;
  }

  Future<void> acceptIncoming() async {
    final session = activeSession.value;
    if (session == null || session.phase != AppCallPhase.incomingRinging) {
      return;
    }
    final me = _currentUser;
    final response = session.signal.copyWith(
      action: AppCallAction.accept,
      senderId: me,
      senderName: _currentDisplayName,
      receiverId: session.signal.senderId,
    );
    _send(response);
    activeSession.value = session.copyWith(
      phase: AppCallPhase.connecting,
      acceptedParticipants: {...session.acceptedParticipants, me},
    );
    _ringTimeout?.cancel();
    _openCall(replace: true);
  }

  Future<void> rejectIncoming() async {
    final session = activeSession.value;
    if (session == null) return;
    _send(
      session.signal.copyWith(
        action: AppCallAction.reject,
        senderId: _currentUser,
        senderName: _currentDisplayName,
        receiverId: session.signal.senderId,
      ),
    );
    _finish('已拒绝');
    _closeTopCallRoute();
  }

  Future<void> cancelOutgoing() async {
    final session = activeSession.value;
    if (session == null) return;
    _send(session.signal.copyWith(action: AppCallAction.cancel));
    _finish('已取消');
    _closeTopCallRoute();
  }

  Future<void> hangup() async {
    final session = activeSession.value;
    if (session == null) return;
    final action = session.signal.isGroup && session.isCaller
        ? AppCallAction.end
        : AppCallAction.hangup;
    final receiver = session.signal.isGroup
        ? ''
        : session.isCaller
        ? session.signal.receiverId
        : session.signal.senderId;
    _send(
      session.signal.copyWith(
        action: action,
        senderId: _currentUser,
        senderName: _currentDisplayName,
        receiverId: receiver,
      ),
    );
    _finish('通话结束');
  }

  void markConnected() {
    final session = activeSession.value;
    if (session == null || session.phase == AppCallPhase.connected) return;
    activeSession.value = session.copyWith(phase: AppCallPhase.connected);
  }

  bool _canStartCall() {
    initialize();
    return activeSession.value == null &&
        _currentUser.isNotEmpty &&
        WebSocketManager().isConnected;
  }

  AppCallSignal _newSignal({
    required AppCallKind kind,
    required String title,
    String receiverId = '',
    int groupId = 0,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final suffix = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    final callId = '${kind.name}_${_currentUser}_${now}_$suffix';
    return AppCallSignal(
      callId: callId,
      kind: kind,
      action: AppCallAction.invite,
      channelName: 'quanxin_$callId',
      senderId: _currentUser,
      senderName: _currentDisplayName,
      receiverId: receiverId,
      groupId: groupId,
      groupName: kind == AppCallKind.group ? title : '',
      sentAt: now,
    );
  }

  void _handleMessage(dynamic raw) {
    final signal = AppCallSignal.tryParse(raw);
    if (signal == null || signal.senderId == _currentUser) return;
    final current = activeSession.value;
    if (signal.action == AppCallAction.invite) {
      if (current != null && current.signal.callId != signal.callId) {
        _send(
          signal.copyWith(
            action: AppCallAction.busy,
            senderId: _currentUser,
            senderName: _currentDisplayName,
            receiverId: signal.senderId,
            reason: 'busy',
          ),
        );
        return;
      }
      if (current != null) return;
      activeSession.value = AppCallSession(
        signal: signal,
        phase: AppCallPhase.incomingRinging,
        isCaller: false,
      );
      _startRingTimeout(incoming: true);
      _openLobby();
      return;
    }
    if (current == null || current.signal.callId != signal.callId) return;
    switch (signal.action) {
      case AppCallAction.accept:
        final accepted = {...current.acceptedParticipants, signal.senderId};
        activeSession.value = current.copyWith(
          phase: AppCallPhase.connecting,
          acceptedParticipants: accepted,
        );
        _ringTimeout?.cancel();
        if (current.phase == AppCallPhase.outgoingRinging) {
          _openCall(replace: true);
        }
      case AppCallAction.reject:
        if (!current.signal.isGroup) {
          _finish('对方已拒绝');
          _closeTopCallRoute();
        }
      case AppCallAction.cancel:
        _finish('对方已取消');
        _closeTopCallRoute();
      case AppCallAction.hangup:
        if (!current.signal.isGroup) {
          _finish('对方已挂断');
          _closeTopCallRoute();
        }
      case AppCallAction.end:
        _finish('群视频已结束');
        _closeTopCallRoute();
      case AppCallAction.busy:
        if (!current.signal.isGroup) {
          _finish('对方正在通话中');
          _closeTopCallRoute();
        }
      case AppCallAction.unavailable:
        _finish(_unavailableMessage(signal.reason));
        _closeTopCallRoute();
      case AppCallAction.invite:
        break;
    }
  }

  bool _send(AppCallSignal signal) => WebSocketManager().send(signal.toWire());

  void _startRingTimeout({bool incoming = false}) {
    _ringTimeout?.cancel();
    _ringTimeout = Timer(const Duration(seconds: 45), () {
      final session = activeSession.value;
      if (session == null) return;
      if (incoming) {
        _send(
          session.signal.copyWith(
            action: AppCallAction.reject,
            senderId: _currentUser,
            senderName: _currentDisplayName,
            receiverId: session.signal.senderId,
            reason: 'timeout',
          ),
        );
      } else {
        _send(session.signal.copyWith(action: AppCallAction.cancel));
      }
      _finish('无人接听');
      _closeTopCallRoute();
    });
  }

  void _finish(String reason) {
    _ringTimeout?.cancel();
    final session = activeSession.value;
    if (session != null) {
      activeSession.value = session.copyWith(
        phase: AppCallPhase.ended,
        endReason: reason,
      );
    }
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (activeSession.value?.phase == AppCallPhase.ended) {
        activeSession.value = null;
      }
    });
  }

  void _openLobby() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GlobalNavigatorKey.navigatorState?.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/callLobby'),
          fullscreenDialog: true,
          builder: (_) => const VideoCallInviteWaitingPage(),
        ),
      );
    });
  }

  void _openCall({required bool replace}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = GlobalNavigatorKey.navigatorState;
      if (navigator == null) return;
      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/videoCall'),
        fullscreenDialog: true,
        builder: (_) => const VideoCallPage(),
      );
      if (replace) {
        navigator.pushReplacement(route);
      } else {
        navigator.push(route);
      }
    });
  }

  void _closeTopCallRoute() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = GlobalNavigatorKey.navigatorState;
      if (navigator?.canPop() == true) navigator?.pop();
    });
  }

  String get _currentUser => GlobalUtil().userName?.trim() ?? '';

  String get _currentDisplayName {
    final user = GlobalUtil().userInfoModel;
    final nickname = user.nickName?.trim() ?? '';
    return nickname.isEmpty ? _currentUser : nickname;
  }

  String _unavailableMessage(String reason) {
    return switch (reason) {
      'offline' => '对方当前不在线',
      'not_friends' => '对方已不是你的好友',
      'not_group_member' => '你已不在该群聊中',
      'no_group_members' => '暂无可邀请的群成员',
      _ => '对方当前无法接听',
    };
  }
}
