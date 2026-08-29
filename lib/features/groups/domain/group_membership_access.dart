import '../../../model/groupInfoModel.dart';
import '../../../model/groupMemberModel.dart';

bool hasGroupAccess({
  required String userId,
  required int groupId,
  required Iterable<GroupMemberModel> members,
  required Iterable<GroupInfoModel> visibleGroups,
}) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) return false;

  final isActiveMember = members.any(
    (member) => member.userId == normalizedUserId && member.isQuit == 0,
  );
  if (isActiveMember) return true;

  // Some server versions keep the owner only on the group record instead of
  // returning it in the member list. A group returned by getGroups is also an
  // authoritative indication that the current user still has access.
  return visibleGroups.any(
    (group) => group.groupId == groupId && group.isActive == 1,
  );
}
