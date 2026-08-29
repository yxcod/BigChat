class GroupRolePolicy {
  const GroupRolePolicy._();

  static const int member = 0;
  static const int administrator = 1;
  static const int owner = 2;

  static bool canManageMembers(int actorRole) => actorRole >= administrator;

  static bool canRemove({required int actorRole, required int targetRole}) {
    if (actorRole == owner) return targetRole < owner;
    return actorRole == administrator && targetRole == member;
  }

  static bool canChangeRole({required int actorRole, required int targetRole}) {
    return actorRole == owner && targetRole != owner;
  }

  static bool canMute({required int actorRole, required int targetRole}) {
    if (actorRole == owner) return targetRole < owner;
    return actorRole == administrator && targetRole == member;
  }

  static bool canManageTarget({
    required int actorRole,
    required int targetRole,
  }) {
    return canChangeRole(actorRole: actorRole, targetRole: targetRole) ||
        canMute(actorRole: actorRole, targetRole: targetRole);
  }
}
