import 'package:flutter_base/features/groups/application/group_membership_verifier.dart';
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

  test('active member does not require a visible-groups request', () async {
    var loaderCalled = false;
    final result = await resolveGroupMembership(
      userId: 'owner',
      groupId: 7,
      members: [GroupMemberModel(groupId: 7, userId: 'owner', role: 2)],
      loadVisibleGroups: (_) async {
        loaderCalled = true;
        return const [];
      },
    );

    expect(result.hasAccess, isTrue);
    expect(result.removalConfirmed, isFalse);
    expect(result.currentMember?.role, 2);
    expect(loaderCalled, isFalse);
  });

  test(
    'visible owner remains accessible when member response is empty',
    () async {
      final result = await resolveGroupMembership(
        userId: 'owner',
        groupId: 7,
        members: const [],
        loadVisibleGroups: (_) async => [
          GroupInfoModel(groupId: 7, groupName: '测试群', creatorId: 'owner'),
        ],
      );

      expect(result.hasAccess, isTrue);
      expect(result.removalConfirmed, isFalse);
      expect(result.visibleGroup?.creatorId, 'owner');
    },
  );

  test('empty member response cannot confirm removal', () async {
    final result = await resolveGroupMembership(
      userId: 'owner',
      groupId: 7,
      members: const [],
      loadVisibleGroups: (_) async => const [],
    );

    expect(result.hasAccess, isFalse);
    expect(result.removalConfirmed, isFalse);
  });

  test('non-empty member response can confirm removal', () async {
    final result = await resolveGroupMembership(
      userId: 'former-member',
      groupId: 7,
      members: [GroupMemberModel(groupId: 7, userId: 'member')],
      loadVisibleGroups: (_) async => const [],
    );

    expect(result.hasAccess, isFalse);
    expect(result.removalConfirmed, isTrue);
  });
}
