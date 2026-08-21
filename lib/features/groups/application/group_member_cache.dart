import '../../../model/groupMemberModel.dart';

class GroupMemberCache {
  final Map<int, List<GroupMemberModel>> _membersByGroup = {};

  void put(int groupId, List<GroupMemberModel> members) {
    _membersByGroup[groupId] = List<GroupMemberModel>.of(members);
  }

  List<GroupMemberModel> get(int groupId) {
    return List<GroupMemberModel>.unmodifiable(
      _membersByGroup[groupId] ?? const [],
    );
  }

  void remove(int groupId) {
    _membersByGroup.remove(groupId);
  }

  void clear() {
    _membersByGroup.clear();
  }
}
