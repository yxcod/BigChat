import '../../../core/parsing/json_value_parser.dart';

enum ChatRealtimeEventType {
  privateMessage,
  groupMessage,
  privateDelivery,
  groupDelivery,
  groupReadReceipt,
  groupHistoryDeleted,
  readReceipt,
  other,
}

class ChatRealtimeEvent {
  const ChatRealtimeEvent({required this.type, required this.data});

  final ChatRealtimeEventType type;
  final Map<String, dynamic> data;

  factory ChatRealtimeEvent.parse(Map<String, dynamic> data) {
    final rawType = JsonValueParser.stringValue(data['type']);
    final type = switch (rawType) {
      'message' => ChatRealtimeEventType.privateMessage,
      'groupChat' => ChatRealtimeEventType.groupMessage,
      'delivery_ack' => ChatRealtimeEventType.privateDelivery,
      'groupChatCallback'
          when data.containsKey('clientMsgId') && data['status'] != 'read' =>
        ChatRealtimeEventType.groupDelivery,
      'groupChatReadCallback' => ChatRealtimeEventType.groupReadReceipt,
      'groupChatHistoryDeleted' => ChatRealtimeEventType.groupHistoryDeleted,
      'read_ack' ||
      'chatCallback' ||
      'groupChatCallback' => ChatRealtimeEventType.readReceipt,
      _ => ChatRealtimeEventType.other,
    };
    return ChatRealtimeEvent(type: type, data: data);
  }

  int get messageId => JsonValueParser.intValue(data['msgId']);
  int get clientMessageId => JsonValueParser.intValue(data['clientMsgId']);
  int get timestamp => JsonValueParser.timestampMillis(
    data['sendTime'],
    fallback: DateTime.now().millisecondsSinceEpoch,
  );
  int get messageType => JsonValueParser.intValue(data['msgType'], fallback: 1);
  int get groupId => JsonValueParser.intValue(
    data['groupId'] ?? data['sessionId'] ?? data['receiveId'],
  );
  int get code => JsonValueParser.intValue(data['code']);
  String get senderId => JsonValueParser.stringValue(data['sendUserId']);
  String get content => JsonValueParser.stringValue(data['msgContent']);
  String get conversationId => JsonValueParser.stringValue(data['sessionId']);
  String get deliveryStatus => JsonValueParser.stringValue(data['status']);
  String get readerId => JsonValueParser.stringValue(data['reader']);
  int get readThroughMessageId =>
      JsonValueParser.intValue(data['readThroughMsgId']);
}
