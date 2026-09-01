import '../../../utils/http.dart';
import '../domain/moment_interaction_notification.dart';
import 'moment_notification_local_storage.dart';

class MomentNotificationPage {
  const MomentNotificationPage({
    required this.items,
    required this.unreadCount,
    required this.hasMore,
  });

  final List<MomentInteractionNotification> items;
  final int unreadCount;
  final bool hasMore;
}

abstract class MomentNotificationRepository {
  Future<MomentNotificationSnapshot> loadCached(String ownerId);

  Future<MomentNotificationPage> fetch(String ownerId);

  Future<int> fetchUnreadCount(String ownerId);

  Future<void> markAllRead(String ownerId);

  Future<void> saveSnapshot(
    String ownerId,
    MomentNotificationSnapshot snapshot,
  );
}

class ServerMomentNotificationRepository
    implements MomentNotificationRepository {
  ServerMomentNotificationRepository({
    HttpUtil? httpUtil,
    MomentNotificationLocalStorage? localStorage,
  }) : _httpUtil = httpUtil ?? HttpUtil(),
       _localStorage = localStorage ?? FileMomentNotificationStorage();

  final HttpUtil _httpUtil;
  final MomentNotificationLocalStorage _localStorage;

  @override
  Future<MomentNotificationSnapshot> loadCached(String ownerId) {
    return _localStorage.load(ownerId);
  }

  @override
  Future<MomentNotificationPage> fetch(String ownerId) async {
    final response = await _httpUtil.post(
      '/api/moment/notifications',
      data: {'limit': 50},
    );
    final data = _requireData(response.data);
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => MomentInteractionNotification.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false)
        : const <MomentInteractionNotification>[];
    final page = MomentNotificationPage(
      items: items,
      unreadCount: _readInt(data['unreadCount']),
      hasMore: data['hasMore'] == true,
    );
    await saveSnapshot(
      ownerId,
      MomentNotificationSnapshot(
        items: page.items,
        unreadCount: page.unreadCount,
      ),
    );
    return page;
  }

  @override
  Future<int> fetchUnreadCount(String ownerId) async {
    final response = await _httpUtil.post(
      '/api/moment/notifications/unreadCount',
      data: const <String, dynamic>{},
    );
    return _readInt(_requireData(response.data)['unreadCount']);
  }

  @override
  Future<void> markAllRead(String ownerId) async {
    final response = await _httpUtil.post(
      '/api/moment/notifications/readAll',
      data: const <String, dynamic>{},
    );
    _requireData(response.data);
  }

  @override
  Future<void> saveSnapshot(
    String ownerId,
    MomentNotificationSnapshot snapshot,
  ) {
    return _localStorage.save(ownerId, snapshot);
  }

  Map<String, dynamic> _requireData(Object? body) {
    if (body is! Map) throw const FormatException('服务器返回格式错误');
    final envelope = Map<String, dynamic>.from(body);
    if (_readInt(envelope['code']) != 100 || envelope['data'] is! Map) {
      throw StateError(envelope['message']?.toString() ?? '动态通知请求失败');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map);
  }

  int _readInt(Object? value) {
    final result = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '') ?? 0;
    return result < 0 ? 0 : result;
  }
}
