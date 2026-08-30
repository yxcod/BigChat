enum AppCallKind { private, group }

enum AppCallAction {
  invite,
  accept,
  reject,
  cancel,
  hangup,
  end,
  busy,
  unavailable,
}

enum AppCallPhase {
  outgoingRinging,
  incomingRinging,
  connecting,
  connected,
  ended,
}

class AppCallSignal {
  const AppCallSignal({
    required this.callId,
    required this.kind,
    required this.action,
    required this.channelName,
    required this.senderId,
    required this.senderName,
    this.receiverId = '',
    this.groupId = 0,
    this.groupName = '',
    this.token = '',
    this.sentAt = 0,
    this.reason = '',
  });

  final String callId;
  final AppCallKind kind;
  final AppCallAction action;
  final String channelName;
  final String senderId;
  final String senderName;
  final String receiverId;
  final int groupId;
  final String groupName;
  final String token;
  final int sentAt;
  final String reason;

  bool get isGroup => kind == AppCallKind.group;

  AppCallSignal copyWith({
    AppCallAction? action,
    String? senderId,
    String? senderName,
    String? receiverId,
    String? token,
    String? reason,
  }) {
    return AppCallSignal(
      callId: callId,
      kind: kind,
      action: action ?? this.action,
      channelName: channelName,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      receiverId: receiverId ?? this.receiverId,
      groupId: groupId,
      groupName: groupName,
      token: token ?? this.token,
      sentAt: DateTime.now().millisecondsSinceEpoch,
      reason: reason ?? this.reason,
    );
  }

  Map<String, dynamic> toWire() {
    return {
      'type': 'callSignal',
      'callId': callId,
      'callKind': kind.name,
      'action': action.name,
      'channelName': channelName,
      'sender': senderId,
      'senderName': senderName,
      if (receiverId.isNotEmpty) 'receiver': receiverId,
      if (groupId > 0) 'groupId': groupId,
      if (groupName.isNotEmpty) 'groupName': groupName,
      if (token.isNotEmpty) 'token': token,
      'time': sentAt == 0 ? DateTime.now().millisecondsSinceEpoch : sentAt,
      if (reason.isNotEmpty) 'reason': reason,
    };
  }

  static AppCallSignal? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final data = Map<String, dynamic>.from(raw);
    final type = _text(data['type']);
    AppCallAction? action;
    if (type == 'callSignal') {
      action = AppCallAction.values
          .where((value) => value.name == _text(data['action']))
          .firstOrNull;
    } else {
      action = switch (type) {
        'videoCallInvite' || 'groupVideoCallInvite' => AppCallAction.invite,
        'videoCallAccept' || 'groupVideoCallAccept' => AppCallAction.accept,
        'videoCallReject' || 'groupVideoCallReject' => AppCallAction.reject,
        'videoCallHangup' || 'groupVideoCallHangup' => AppCallAction.hangup,
        _ => null,
      };
    }
    if (action == null) return null;
    final groupId = _integer(data['groupId']);
    final kind =
        _text(data['callKind']) == 'group' ||
            type.startsWith('groupVideo') ||
            groupId > 0
        ? AppCallKind.group
        : AppCallKind.private;
    final sender = _text(data['sender']);
    final channel = _text(data['channelName']);
    final callId = _text(data['callId']).isNotEmpty
        ? _text(data['callId'])
        : channel;
    if (callId.isEmpty || channel.isEmpty || sender.isEmpty) return null;
    return AppCallSignal(
      callId: callId,
      kind: kind,
      action: action,
      channelName: channel,
      senderId: sender,
      senderName: _text(data['senderName']).isEmpty
          ? sender
          : _text(data['senderName']),
      receiverId: _text(data['receiver']),
      groupId: groupId,
      groupName: _text(data['groupName']),
      token: _text(data['token']),
      sentAt: _integer(data['time']),
      reason: _text(data['reason']),
    );
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static int _integer(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class AppCallSession {
  const AppCallSession({
    required this.signal,
    required this.phase,
    required this.isCaller,
    this.acceptedParticipants = const <String>{},
    this.endReason = '',
  });

  final AppCallSignal signal;
  final AppCallPhase phase;
  final bool isCaller;
  final Set<String> acceptedParticipants;
  final String endReason;

  AppCallSession copyWith({
    AppCallSignal? signal,
    AppCallPhase? phase,
    Set<String>? acceptedParticipants,
    String? endReason,
  }) {
    return AppCallSession(
      signal: signal ?? this.signal,
      phase: phase ?? this.phase,
      isCaller: isCaller,
      acceptedParticipants: acceptedParticipants ?? this.acceptedParticipants,
      endReason: endReason ?? this.endReason,
    );
  }
}
