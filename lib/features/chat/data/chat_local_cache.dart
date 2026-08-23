import 'dart:convert';
import 'dart:io';

import '../../../model/messageModel.dart';
import 'package:path_provider/path_provider.dart';

typedef CacheStringReader = Future<String?> Function(String key);
typedef CacheStringWriter = Future<void> Function(String key, String value);
typedef CacheStringDeleter = Future<void> Function(String key);

class ChatLocalCache {
  ChatLocalCache({
    CacheStringReader? readString,
    CacheStringWriter? writeString,
    CacheStringDeleter? deleteString,
  }) : _readString = readString,
       _writeString = writeString,
       _deleteString = deleteString;

  final CacheStringReader? _readString;
  final CacheStringWriter? _writeString;
  final CacheStringDeleter? _deleteString;

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
    final key = cacheKey(ownerId, conversationId);
    if (_writeString != null) {
      await _writeString(key, json);
      return;
    }
    final file = await _cacheFile(key);
    await file.parent.create(recursive: true);
    await file.writeAsString(json, flush: true);
  }

  Future<List<Message>> load(String ownerId, String conversationId) async {
    try {
      final key = cacheKey(ownerId, conversationId);
      final json = _readString != null
          ? await _readString(key)
          : await _readCacheFile(key);
      if (json == null || json.isEmpty) return const [];

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

  Future<int> latestTimestamp(String ownerId, String conversationId) async {
    final messages = await load(ownerId, conversationId);
    return messages.fold<int>(
      0,
      (latest, message) =>
          message.timestamp > latest ? message.timestamp : latest,
    );
  }

  Future<void> delete(String ownerId, String conversationId) async {
    final key = cacheKey(ownerId, conversationId);
    if (_deleteString != null) {
      await _deleteString(key);
      return;
    }
    if (_writeString != null) {
      await _writeString(key, '');
      return;
    }
    final file = await _cacheFile(key);
    if (await file.exists()) await file.delete();
  }

  Future<File> _cacheFile(String key) async {
    final documents = await getApplicationDocumentsDirectory();
    return File('${documents.path}/chat_cache/$key.json');
  }

  Future<String?> _readCacheFile(String key) async {
    final file = await _cacheFile(key);
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}
