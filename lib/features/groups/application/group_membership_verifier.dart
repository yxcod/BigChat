import '../../../api/getGroupInfoAPI.dart';
import '../../../model/groupInfoModel.dart';
import '../../../model/groupMemberModel.dart';
import '../domain/group_membership_access.dart';

typedef VisibleGroupsLoader =
    Future<List<GroupInfoModel>> Function(String userId);

class GroupMembershipResolution {
  const GroupMembershipResolution({
    required this.hasAccess,
    required this.removalConfirmed,
    this.currentMember,
    this.visibleGroup,
  });

  final bool hasAccess;
  final bool removalConfirmed;
  final GroupMemberModel? currentMember;
  final GroupInfoModel? visibleGroup;
}

Future<GroupMembershipResolution> resolveGroupMembership({
  required String userId,
  required int groupId,
  required List<GroupMemberModel> members,
  VisibleGroupsLoader loadVisibleGroups = getGroups,
}) async {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    throw StateError('Current user identity is unavailable');
  }

  GroupMemberModel? currentMember;
  for (final member in members) {
    if (member.userId == normalizedUserId && member.isQuit == 0) {
      currentMember = member;
      break;
    }
  }
  if (currentMember != null) {
    return GroupMembershipResolution(
      hasAccess: true,
      removalConfirmed: false,
      currentMember: currentMember,
    );
  }

  final visibleGroups = await loadVisibleGroups(normalizedUserId);
  GroupInfoModel? visibleGroup;
  for (final group in visibleGroups) {
    if (group.groupId == groupId && group.isActive == 1) {
      visibleGroup = group;
      break;
    }
  }
  return GroupMembershipResolution(
    hasAccess: hasGroupAccess(
      userId: normalizedUserId,
      groupId: groupId,
      members: members,
      visibleGroups: visibleGroups,
    ),
    // An empty member response is not authoritative: older servers can return
    // it after a query/schema failure. Explicit realtime removal events remain
    // the source of truth in that case.
    removalConfirmed: members.isNotEmpty && visibleGroup == null,
    visibleGroup: visibleGroup,
  );
}
