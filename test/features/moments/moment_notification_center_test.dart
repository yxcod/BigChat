import 'package:flutter/material.dart';
import 'package:flutter_base/features/moments/application/moment_notification_center.dart';
import 'package:flutter_base/features/moments/data/moment_notification_local_storage.dart';
import 'package:flutter_base/features/moments/data/moment_notification_repository.dart';
import 'package:flutter_base/features/moments/domain/moment_interaction_notification.dart';
import 'package:flutter_base/features/moments/presentation/moment_notifications_page.dart';
import 'package:flutter_base/pages/mainPages/ProfilePage.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUp(() {
    GlobalUtil().userName = 'owner_100';
  });

  tearDown(() {
    GlobalUtil().userName = null;
  });

  test(
    'cached unread state is restored and realtime updates stay persisted',
    () async {
      final repository = _FakeRepository(
        cached: MomentNotificationSnapshot(
          items: [_notification(id: '1')],
          unreadCount: 1,
        ),
      );
      final center = MomentNotificationCenter(repository: repository);

      await center.initialize(refreshFromServer: false);
      expect(center.unreadCount, 1);
      expect(center.items.single.id, '1');

      await center.handleRealtime({
        ..._notification(id: '2', type: MomentInteractionType.comment).toJson(),
        'unreadCount': 2,
      });
      expect(center.unreadCount, 2);
      expect(center.items.first.id, '2');
      expect(repository.saved?.unreadCount, 2);

      await center.markAllRead();
      expect(center.unreadCount, 0);
      expect(center.items.every((item) => item.isRead), isTrue);
      expect(repository.markReadCalls, 1);
    },
  );

  testWidgets(
    'profile space card shows a red dot when interactions are unread',
    (tester) async {
      final center = MomentNotificationCenter(
        repository: _FakeRepository(
          cached: MomentNotificationSnapshot(
            items: [_notification(id: '1')],
            unreadCount: 1,
          ),
        ),
      );
      await center.initialize(refreshFromServer: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ProfilePage(autoLoad: false, notificationCenter: center),
        ),
      );

      expect(
        find.byKey(const ValueKey('moment_notification_unread_dot')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'interaction page renders comments and marks notifications read',
    (tester) async {
      final repository = _FakeRepository(
        cached: const MomentNotificationSnapshot(items: [], unreadCount: 0),
        serverItems: [
          _notification(id: '7', type: MomentInteractionType.comment),
        ],
        serverUnreadCount: 1,
      );
      final center = MomentNotificationCenter(repository: repository);

      await tester.pumpWidget(
        MaterialApp(home: MomentNotificationsPage(notificationCenter: center)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('评论了你的动态'), findsOneWidget);
      expect(find.text('这是一条评论'), findsOneWidget);
      expect(repository.markReadCalls, 1);
      expect(center.unreadCount, 0);
    },
  );
}

MomentInteractionNotification _notification({
  required String id,
  MomentInteractionType type = MomentInteractionType.like,
}) {
  return MomentInteractionNotification(
    id: id,
    actorUserId: 'friend_200',
    actorName: '好友小明',
    actorAvatarUrl: '',
    momentId: '88',
    type: type,
    commentContent: type == MomentInteractionType.comment ? '这是一条评论' : '',
    isRead: false,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1788235200000),
  );
}

class _FakeRepository implements MomentNotificationRepository {
  _FakeRepository({
    required this.cached,
    this.serverItems = const [],
    this.serverUnreadCount = 0,
  });

  final MomentNotificationSnapshot cached;
  final List<MomentInteractionNotification> serverItems;
  final int serverUnreadCount;
  MomentNotificationSnapshot? saved;
  int markReadCalls = 0;

  @override
  Future<MomentNotificationPage> fetch(String ownerId) async {
    return MomentNotificationPage(
      items: serverItems,
      unreadCount: serverUnreadCount,
      hasMore: false,
    );
  }

  @override
  Future<int> fetchUnreadCount(String ownerId) async => serverUnreadCount;

  @override
  Future<MomentNotificationSnapshot> loadCached(String ownerId) async => cached;

  @override
  Future<void> markAllRead(String ownerId) async {
    markReadCalls++;
  }

  @override
  Future<void> saveSnapshot(
    String ownerId,
    MomentNotificationSnapshot snapshot,
  ) async {
    saved = snapshot;
  }
}
