import 'package:flutter/foundation.dart';

import '../../../utils/gloabl.dart';
import '../data/moment_notification_local_storage.dart';
import '../data/moment_notification_repository.dart';
import '../domain/moment_interaction_notification.dart';

class MomentNotificationCenter extends ChangeNotifier {
  MomentNotificationCenter({MomentNotificationRepository? repository})
    : _repository = repository ?? ServerMomentNotificationRepository();

  static final MomentNotificationCenter instance = MomentNotificationCenter();

  final MomentNotificationRepository _repository;
  List<MomentInteractionNotification> _items = const [];
  int _unreadCount = 0;
  String _ownerId = '';
  bool _initializing = false;

  List<MomentInteractionNotification> get items => _items;
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  Future<void> initialize({bool refreshFromServer = true}) async {
    final ownerId = GlobalUtil().userName?.trim() ?? '';
    if (ownerId.isEmpty || _initializing) return;
    _initializing = true;
    try {
      if (_ownerId != ownerId) {
        _ownerId = ownerId;
        final cached = await _repository.loadCached(ownerId);
        _items = List.unmodifiable(cached.items);
        _unreadCount = cached.unreadCount;
        notifyListeners();
      }
      if (refreshFromServer) await refresh();
    } finally {
      _initializing = false;
    }
  }

  Future<void> refresh() async {
    final ownerId = _currentOwnerId();
    if (ownerId.isEmpty) return;
    try {
      final page = await _repository.fetch(ownerId);
      _items = List.unmodifiable(page.items);
      _unreadCount = page.unreadCount;
      notifyListeners();
    } catch (error) {
      debugPrint('刷新动态互动通知失败：$error');
    }
  }

  Future<void> refreshUnreadCount() async {
    final ownerId = _currentOwnerId();
    if (ownerId.isEmpty) return;
    try {
      _unreadCount = await _repository.fetchUnreadCount(ownerId);
      notifyListeners();
      await _persist();
    } catch (error) {
      debugPrint('刷新动态互动未读数失败：$error');
    }
  }

  Future<MomentInteractionNotification?> handleRealtime(
    Map<String, dynamic> event,
  ) async {
    final ownerId = _currentOwnerId();
    if (ownerId.isEmpty) return null;
    final notification = MomentInteractionNotification.fromJson(event);
    if (notification.id.isEmpty || notification.actorUserId.isEmpty) {
      return null;
    }
    _items = List.unmodifiable(
      [
        notification,
        ..._items.where((item) => item.id != notification.id),
      ].take(50),
    );
    final serverUnread = _readInt(event['unreadCount']);
    _unreadCount = serverUnread > 0 ? serverUnread : _unreadCount + 1;
    notifyListeners();
    await _persist();
    return notification;
  }

  Future<void> markAllRead() async {
    final ownerId = _currentOwnerId();
    if (ownerId.isEmpty || _unreadCount == 0) return;
    try {
      await _repository.markAllRead(ownerId);
      _unreadCount = 0;
      _items = List.unmodifiable(
        _items.map((item) => item.copyWith(isRead: true)),
      );
      notifyListeners();
      await _persist();
    } catch (error) {
      debugPrint('标记动态互动通知已读失败：$error');
    }
  }

  void reset() {
    _ownerId = '';
    _items = const [];
    _unreadCount = 0;
    notifyListeners();
  }

  String _currentOwnerId() {
    final current = GlobalUtil().userName?.trim() ?? '';
    if (current.isNotEmpty && current != _ownerId) _ownerId = current;
    return _ownerId;
  }

  Future<void> _persist() {
    if (_ownerId.isEmpty) return Future.value();
    return _repository.saveSnapshot(
      _ownerId,
      MomentNotificationSnapshot(items: _items, unreadCount: _unreadCount),
    );
  }

  int _readInt(Object? value) {
    return value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
