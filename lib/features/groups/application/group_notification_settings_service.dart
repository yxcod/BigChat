import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/gloabl.dart';

/// 按账号、按群保存消息免打扰状态。
///
/// 这是设备通知偏好，不写入聊天数据库；切换账号时会加载对应账号自己的设置。
class GroupNotificationSettingsService extends ChangeNotifier {
  GroupNotificationSettingsService();

  static final GroupNotificationSettingsService instance =
      GroupNotificationSettingsService();

  String _ownerId = '';
  Set<int> _mutedGroupIds = <int>{};

  String get ownerId => _ownerId;

  String _storageKey(String ownerId) =>
      'group_notification_muted_${Uri.encodeComponent(ownerId)}';

  Future<void> load({String? ownerId}) async {
    final resolvedOwner = (ownerId ?? GlobalUtil().userName ?? '').trim();
    if (resolvedOwner == _ownerId) return;
    _ownerId = resolvedOwner;
    final preferences = await SharedPreferences.getInstance();
    final stored = resolvedOwner.isEmpty
        ? const <String>[]
        : preferences.getStringList(_storageKey(resolvedOwner)) ??
              const <String>[];
    _mutedGroupIds = stored
        .map(int.tryParse)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
    notifyListeners();
  }

  Future<void> ensureCurrentUserLoaded() async {
    final currentOwner = (GlobalUtil().userName ?? '').trim();
    if (currentOwner != _ownerId) await load(ownerId: currentOwner);
  }

  bool isMuted(int groupId) => groupId > 0 && _mutedGroupIds.contains(groupId);

  Future<bool> isCurrentUserMuted(int groupId) async {
    await ensureCurrentUserLoaded();
    return isMuted(groupId);
  }

  Future<void> setMuted(int groupId, bool muted) async {
    if (groupId <= 0) return;
    await ensureCurrentUserLoaded();
    final changed = muted
        ? _mutedGroupIds.add(groupId)
        : _mutedGroupIds.remove(groupId);
    if (!changed) return;
    final values = _mutedGroupIds.map((id) => id.toString()).toList()..sort();
    if (_ownerId.isNotEmpty) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_storageKey(_ownerId), values);
    }
    notifyListeners();
  }
}
