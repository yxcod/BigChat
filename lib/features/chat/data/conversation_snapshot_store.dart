import 'dart:convert';

import '../../../utils/storageUtil.dart';

typedef ConversationSnapshotReader = String? Function(String key);
typedef ConversationSnapshotWriter =
    Future<void> Function(String key, String value);

/// User-scoped, display-ready conversation snapshots used during cold start.
///
/// Only ordinary server-backed conversation data belongs here. Privacy
/// messages are kept in memory by the caller and must never be serialized into
/// these snapshots.
class ConversationSnapshotStore {
  ConversationSnapshotStore({
    ConversationSnapshotReader? readString,
    ConversationSnapshotWriter? writeString,
  }) : _readString = readString ?? StorageUtil.getString,
       _writeString =
           writeString ??
           ((key, value) async {
             await StorageUtil.setString(key, value);
           });

  final ConversationSnapshotReader _readString;
  final ConversationSnapshotWriter _writeString;

  String storageKey(String ownerId) =>
      'conversation_snapshot_v1_${Uri.encodeComponent(ownerId)}';

  List<Map<String, dynamic>> load(String ownerId) {
    if (ownerId.trim().isEmpty) return const [];
    try {
      final raw = _readString(storageKey(ownerId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(
    String ownerId,
    Iterable<Map<String, dynamic>> conversations,
  ) async {
    if (ownerId.trim().isEmpty) return;
    await _writeString(storageKey(ownerId), jsonEncode(conversations.toList()));
  }
}
