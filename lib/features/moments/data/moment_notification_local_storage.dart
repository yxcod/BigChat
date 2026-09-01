import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/moment_interaction_notification.dart';

class MomentNotificationSnapshot {
  const MomentNotificationSnapshot({
    required this.items,
    required this.unreadCount,
  });

  final List<MomentInteractionNotification> items;
  final int unreadCount;
}

abstract class MomentNotificationLocalStorage {
  Future<MomentNotificationSnapshot> load(String ownerId);

  Future<void> save(String ownerId, MomentNotificationSnapshot snapshot);
}

class InMemoryMomentNotificationStorage
    implements MomentNotificationLocalStorage {
  final Map<String, MomentNotificationSnapshot> _snapshots = {};

  @override
  Future<MomentNotificationSnapshot> load(String ownerId) async {
    return _snapshots[ownerId] ??
        const MomentNotificationSnapshot(items: [], unreadCount: 0);
  }

  @override
  Future<void> save(String ownerId, MomentNotificationSnapshot snapshot) async {
    _snapshots[ownerId] = MomentNotificationSnapshot(
      items: List.unmodifiable(snapshot.items),
      unreadCount: snapshot.unreadCount,
    );
  }
}

class FileMomentNotificationStorage implements MomentNotificationLocalStorage {
  FileMomentNotificationStorage({
    Future<Directory> Function()? directoryProvider,
  }) : _directoryProvider =
           directoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _directoryProvider;

  Future<File> _file(String ownerId) async {
    final directory = await _directoryProvider();
    final cacheDirectory = Directory('${directory.path}/moment_notifications');
    if (!await cacheDirectory.exists()) {
      await cacheDirectory.create(recursive: true);
    }
    final safeOwner = ownerId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return File('${cacheDirectory.path}/$safeOwner.json');
  }

  @override
  Future<MomentNotificationSnapshot> load(String ownerId) async {
    try {
      final file = await _file(ownerId);
      if (!await file.exists()) {
        return const MomentNotificationSnapshot(items: [], unreadCount: 0);
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return const MomentNotificationSnapshot(items: [], unreadCount: 0);
      }
      final map = Map<String, dynamic>.from(decoded);
      final rawItems = map['items'];
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
      final unreadCount = map['unreadCount'] is num
          ? (map['unreadCount'] as num).toInt()
          : int.tryParse(map['unreadCount']?.toString() ?? '') ?? 0;
      return MomentNotificationSnapshot(
        items: items,
        unreadCount: unreadCount < 0 ? 0 : unreadCount,
      );
    } catch (_) {
      return const MomentNotificationSnapshot(items: [], unreadCount: 0);
    }
  }

  @override
  Future<void> save(String ownerId, MomentNotificationSnapshot snapshot) async {
    final file = await _file(ownerId);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode({
        'unreadCount': snapshot.unreadCount,
        'items': snapshot.items.map((item) => item.toJson()).toList(),
      }),
      flush: true,
    );
    if (await file.exists()) await file.delete();
    await temporary.rename(file.path);
  }
}
