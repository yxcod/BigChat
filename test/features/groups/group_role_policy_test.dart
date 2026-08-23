import 'package:flutter_base/features/groups/domain/group_role_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner can remove administrators and members but not the owner', () {
    expect(
      GroupRolePolicy.canRemove(
        actorRole: GroupRolePolicy.owner,
        targetRole: GroupRolePolicy.administrator,
      ),
      isTrue,
    );
    expect(
      GroupRolePolicy.canRemove(
        actorRole: GroupRolePolicy.owner,
        targetRole: GroupRolePolicy.member,
      ),
      isTrue,
    );
    expect(
      GroupRolePolicy.canRemove(
        actorRole: GroupRolePolicy.owner,
        targetRole: GroupRolePolicy.owner,
      ),
      isFalse,
    );
  });

  test('administrator can remove only ordinary members', () {
    expect(
      GroupRolePolicy.canRemove(
        actorRole: GroupRolePolicy.administrator,
        targetRole: GroupRolePolicy.member,
      ),
      isTrue,
    );
    expect(
      GroupRolePolicy.canRemove(
        actorRole: GroupRolePolicy.administrator,
        targetRole: GroupRolePolicy.administrator,
      ),
      isFalse,
    );
  });

  test('only owner can change non-owner roles', () {
    expect(
      GroupRolePolicy.canChangeRole(
        actorRole: GroupRolePolicy.owner,
        targetRole: GroupRolePolicy.member,
      ),
      isTrue,
    );
    expect(
      GroupRolePolicy.canChangeRole(
        actorRole: GroupRolePolicy.administrator,
        targetRole: GroupRolePolicy.member,
      ),
      isFalse,
    );
  });
}
