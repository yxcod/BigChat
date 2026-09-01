import 'dart:convert';

import '../../../model/groupInfoModel.dart';
import '../../../model/groupMemberModel.dart';
import '../../../utils/storageUtil.dart';

typedef GroupDataReader = String? Function(String key);
typedef GroupDataWriter = Future<void> Function(String key, String value);
typedef GroupDataDeleter = Future<void> Function(String key);

class GroupDataCache {
  GroupDataCache({
    GroupDataReader? readString,
    GroupDataWriter? writeString,
    GroupDataDeleter? deleteString,
  }) : _readString = readString ?? StorageUtil.getString,
       _writeString =
           writeString ??
           ((key, value) async {
             await StorageUtil.setString(key, value);
           }),
       _deleteString = deleteString ?? StorageUtil.remove;

  final GroupDataReader _readString;
  final GroupDataWriter _writeString;
  final GroupDataDeleter _deleteString;

  String groupsKey(String ownerId) =>
      'group_info_snapshot_v1_${Uri.encodeComponent(ownerId)}';

  String membersKey(String ownerId, int groupId) =>
      'group_members_snapshot_v1_${Uri.encodeComponent(ownerId)}_$groupId';

  List<GroupInfoModel> loadGroups(String ownerId) {
    return _loadList(groupsKey(ownerId))
        .map(GroupInfoModel.fromJson)
        .where((group) => group.groupId > 0)
        .toList(growable: false);
  }

  Future<void> saveGroups(
    String ownerId,
    Iterable<GroupInfoModel> groups,
  ) async {
    if (ownerId.trim().isEmpty) return;
    await _writeString(
      groupsKey(ownerId),
      jsonEncode(groups.map((group) => group.toJson()).toList()),
    );
  }

  List<GroupMemberModel> loadMembers(String ownerId, int groupId) {
    if (ownerId.trim().isEmpty || groupId <= 0) return const [];
    return _loadList(membersKey(ownerId, groupId))
        .map(GroupMemberModel.fromJson)
        .where((member) => member.userId.isNotEmpty && member.isQuit == 0)
        .toList(growable: false);
  }

  Future<void> saveMembers(
    String ownerId,
    int groupId,
    Iterable<GroupMemberModel> members,
  ) async {
    if (ownerId.trim().isEmpty || groupId <= 0) return;
    await _writeString(
      membersKey(ownerId, groupId),
      jsonEncode(members.map((member) => member.toJson()).toList()),
    );
  }

  Future<void> removeMembers(String ownerId, int groupId) async {
    if (ownerId.trim().isEmpty || groupId <= 0) return;
    await _deleteString(membersKey(ownerId, groupId));
  }

  List<Map<String, dynamic>> _loadList(String key) {
    try {
      final raw = _readString(key);
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
}
