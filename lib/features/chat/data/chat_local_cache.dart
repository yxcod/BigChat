import 'dart:convert';

import '../../../model/messageModel.dart';
import '../../../utils/storageUtil.dart';

typedef CacheStringReader = String? Function(String key);
typedef CacheStringWriter = Future<bool> Function(String key, String value);

class ChatLocalCache {
  ChatLocalCache({
    CacheStringReader? readString,
    CacheStringWriter? writeString,
  }) : _readString = readString ?? StorageUtil.getString,
       _writeString = writeString ?? StorageUtil.setString;

  final CacheStringReader _readString;
  final CacheStringWriter _writeString;

  String cacheKey(String ownerId, String conversationId) {
    return 'chat_records_v2_${Uri.encodeComponent(ownerId)}_'
        '${Uri.encodeComponent(conversationId)}';
  }

  Future<void> save(
    String ownerId,
    String conversationId,
    List<Message> messages,
  ) async {
    final json = jsonEncode(
      messages.map((message) => message.toJSON()).toList(),
    );
    await _writeString(cacheKey(ownerId, conversationId), json);
  }

  List<Message> load(String ownerId, String conversationId) {
    final json = _readString(cacheKey(ownerId, conversationId));
    if (json == null || json.isEmpty) return const [];

    try {
      final records = jsonDecode(json);
      if (records is! List) return const [];
      return records
          .whereType<Map>()
          .map(
            (record) => Message.fromJSON(
              record.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  int latestTimestamp(String ownerId, String conversationId) {
    final messages = load(ownerId, conversationId);
    return messages.fold<int>(
      0,
      (latest, message) =>
          message.timestamp > latest ? message.timestamp : latest,
    );
  }
}
