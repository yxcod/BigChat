class GroupRouteRegistry {
  GroupRouteRegistry._();

  static final Map<int, int> _activeRouteCounts = {};

  static void enter(int groupId) {
    if (groupId <= 0) return;
    _activeRouteCounts[groupId] = (_activeRouteCounts[groupId] ?? 0) + 1;
  }

  static void leave(int groupId) {
    final count = _activeRouteCounts[groupId] ?? 0;
    if (count <= 1) {
      _activeRouteCounts.remove(groupId);
    } else {
      _activeRouteCounts[groupId] = count - 1;
    }
  }

  static bool isActive(int groupId) => (_activeRouteCounts[groupId] ?? 0) > 0;

  static void clear() => _activeRouteCounts.clear();
}
