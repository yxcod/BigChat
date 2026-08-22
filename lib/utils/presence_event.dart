import '../core/parsing/json_value_parser.dart';

class PresenceEvent {
  const PresenceEvent({required this.userName, required this.isOnline});

  final String userName;
  final bool isOnline;

  static PresenceEvent? tryParse(dynamic message) {
    final data = JsonValueParser.mapValue(message);
    if (data == null || data['type']?.toString() != 'presence') return null;

    final userName = JsonValueParser.stringValue(data['userName']).trim();
    if (userName.isEmpty || !data.containsKey('onlineStatus')) return null;
    return PresenceEvent(
      userName: userName,
      isOnline: JsonValueParser.boolValue(data['onlineStatus']),
    );
  }
}
