import 'dart:convert';

import '../../../utils/storageUtil.dart';

typedef HiddenMessageReader = String? Function(String key);
typedef HiddenMessageWriter = Future<void> Function(String key, String value);

class HiddenMessagesStore {
  HiddenMessagesStore({
    HiddenMessageReader? readString,
    HiddenMessageWriter? writeString,
  }) : _readString = readString ?? StorageUtil.getString,
       _writeString =
           writeString ??
           ((key, value) async {
             await StorageUtil.setString(key, value);
           });

  static const int _maximumIdsPerConversation = 5000;

  final HiddenMessageReader _readString;
  final HiddenMessageWriter _writeString;
  final Map<String, Future<void>> _pendingWrites = {};
  final Map<String, Set<int>> _sessionHidden = {};

  String storageKey(String ownerId, String conversationId) {
    return 'hidden_chat_messages_v1_${Uri.encodeComponent(ownerId)}_'
        '${Uri.encodeComponent(conversationId)}';
  }

  Set<int> load(String ownerId, String conversationId) {
    if (ownerId.isEmpty || conversationId.isEmpty) return <int>{};
    final key = storageKey(ownerId, conversationId);
    try {
      final raw = _readString(key);
      if (raw == null || raw.isEmpty) {
        return Set<int>.from(_sessionHidden[key] ?? const <int>{});
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return Set<int>.from(_sessionHidden[key] ?? const <int>{});
      }
      final persisted = decoded
          .map((value) => int.tryParse(value.toString()) ?? 0)
          .where((id) => id > 0)
          .toSet();
      persisted.addAll(_sessionHidden[key] ?? const <int>{});
      return persisted;
    } catch (_) {
      return Set<int>.from(_sessionHidden[key] ?? const <int>{});
    }
  }

  Future<void> hide(
    String ownerId,
    String conversationId,
    int messageId,
  ) async {
    if (ownerId.isEmpty || conversationId.isEmpty || messageId <= 0) return;
    final key = storageKey(ownerId, conversationId);
    _sessionHidden.putIfAbsent(key, () => <int>{}).add(messageId);
    final previous = (_pendingWrites[key] ?? Future<void>.value()).catchError(
      (_) {},
    );
    final pending = previous.then(
      (_) => _hideNow(key, ownerId, conversationId, messageId),
    );
    _pendingWrites[key] = pending;
    try {
      await pending;
    } finally {
      if (identical(_pendingWrites[key], pending)) _pendingWrites.remove(key);
    }
  }

  Future<void> _hideNow(
    String key,
    String ownerId,
    String conversationId,
    int messageId,
  ) async {
    final hidden = load(ownerId, conversationId)..add(messageId);
    final ids = hidden.toList()..sort((left, right) => right.compareTo(left));
    if (ids.length > _maximumIdsPerConversation) {
      ids.removeRange(_maximumIdsPerConversation, ids.length);
    }
    await _writeString(key, jsonEncode(ids));
  }

  bool isHidden(String ownerId, String conversationId, int messageId) {
    return load(ownerId, conversationId).contains(messageId);
  }
}
