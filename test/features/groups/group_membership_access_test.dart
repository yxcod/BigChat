import 'package:flutter_base/features/groups/domain/group_membership_access.dart';
import 'package:flutter_base/model/groupInfoModel.dart';
import 'package:flutter_base/model/groupMemberModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active member can access the group', () {
    expect(
      hasGroupAccess(
        userId: 'member',
        groupId: 7,
        members: [GroupMemberModel(groupId: 7, userId: 'member')],
        visibleGroups: const [],
      ),
      isTrue,
    );
  });

  test('group owner remains accessible when omitted from member list', () {
    expect(
      hasGroupAccess(
        userId: 'owner',
        groupId: 7,
        members: [GroupMemberModel(groupId: 7, userId: 'member')],
        visibleGroups: [
          GroupInfoModel(groupId: 7, groupName: '测试群', creatorId: 'owner'),
        ],
      ),
      isTrue,
    );
  });

  test('quit member without a visible group has no access', () {
    expect(
      hasGroupAccess(
        userId: 'former-member',
        groupId: 7,
        members: [
          GroupMemberModel(groupId: 7, userId: 'former-member', isQuit: 1),
        ],
        visibleGroups: const [],
      ),
      isFalse,
    );
  });
}
