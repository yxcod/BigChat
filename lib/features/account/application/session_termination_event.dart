class SessionTerminationEvent {
  const SessionTerminationEvent({required this.title, required this.message});

  final String title;
  final String message;

  static SessionTerminationEvent? parse(dynamic rawMessage) {
    if (rawMessage is! Map) return null;
    final type = rawMessage['type']?.toString();
    if (type != 'sessionReplaced' && type != 'sessionInvalidated') return null;
    final fallback = type == 'sessionReplaced'
        ? '你的账号已在其他设备登录'
        : '登录状态已失效，请重新登录';
    final message = rawMessage['message']?.toString().trim() ?? '';
    return SessionTerminationEvent(
      title: type == 'sessionReplaced' ? '账号已在其他设备登录' : '登录已失效',
      message: message.isEmpty ? fallback : message,
    );
  }
}
