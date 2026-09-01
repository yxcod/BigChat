import 'dart:convert';

import '../../../utils/storageUtil.dart';
import '../domain/group_resource.dart';

typedef GroupResourceCacheReader = String? Function(String key);
typedef GroupResourceCacheWriter =
    Future<void> Function(String key, String value);

class GroupResourceCache {
  GroupResourceCache({
    GroupResourceCacheReader? readString,
    GroupResourceCacheWriter? writeString,
  }) : _readString = readString ?? StorageUtil.getString,
       _writeString =
           writeString ??
           ((key, value) async {
             await StorageUtil.setString(key, value);
           });

  final GroupResourceCacheReader _readString;
  final GroupResourceCacheWriter _writeString;

  String storageKey(String ownerId, int groupId, GroupResourceType type) =>
      'group_resource_snapshot_v1_${Uri.encodeComponent(ownerId)}_${groupId}_${type.name}';

  List<GroupResource> load(
    String ownerId,
    int groupId,
    GroupResourceType type,
  ) {
    if (ownerId.trim().isEmpty || groupId <= 0) return const [];
    try {
      final raw = _readString(storageKey(ownerId, groupId, type));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => GroupResource.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where(
            (item) =>
                item.id > 0 && item.groupId == groupId && item.type == type,
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(
    String ownerId,
    int groupId,
    GroupResourceType type,
    Iterable<GroupResource> resources,
  ) async {
    if (ownerId.trim().isEmpty || groupId <= 0) return;
    await _writeString(
      storageKey(ownerId, groupId, type),
      jsonEncode(resources.map((item) => item.toJson()).toList()),
    );
  }
}
