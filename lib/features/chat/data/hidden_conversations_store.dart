import 'dart:convert';

import '../../../utils/storageUtil.dart';

typedef HiddenConversationReader = String? Function(String key);
typedef HiddenConversationWriter =
    Future<void> Function(String key, String value);

class HiddenConversationsStore {
  HiddenConversationsStore({
    HiddenConversationReader? readString,
    HiddenConversationWriter? writeString,
  }) : _readString = readString ?? StorageUtil.getString,
       _writeString =
           writeString ??
           ((key, value) async {
             await StorageUtil.setString(key, value);
           });

  final HiddenConversationReader _readString;
  final HiddenConversationWriter _writeString;

  String storageKey(String ownerId) =>
      'hidden_chat_conversations_v1_${Uri.encodeComponent(ownerId)}';

  Map<String, int> load(String ownerId) {
    if (ownerId.isEmpty) return {};
    try {
      final raw = _readString(storageKey(ownerId));
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) =>
            MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0),
      )..removeWhere((_, cutoff) => cutoff <= 0);
    } catch (_) {
      return {};
    }
  }

  Future<void> save(String ownerId, Map<String, int> hidden) async {
    if (ownerId.isEmpty) return;
    await _writeString(storageKey(ownerId), jsonEncode(hidden));
  }

  bool shouldHide(Map<String, int> hidden, String key, int updateTime) {
    final cutoff = hidden[key];
    if (cutoff == null) return false;
    return _timestampMillis(updateTime) <= cutoff;
  }

  static int _timestampMillis(int timestamp) {
    if (timestamp > 0 && timestamp < 1000000000000) return timestamp * 1000;
    return timestamp;
  }
}
