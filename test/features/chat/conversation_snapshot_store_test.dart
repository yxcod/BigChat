import 'package:flutter/material.dart';
import 'package:flutter_base/features/chat/data/conversation_snapshot_store.dart';
import 'package:flutter_base/pages/mainPages/chatPage.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_base/utils/storageUtil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageUtil.init();
  });

  tearDown(() {
    GlobalUtil().resetSessionState();
  });

  test('conversation snapshots are isolated by signed-in owner', () async {
    final storage = <String, String>{};
    final store = ConversationSnapshotStore(
      readString: (key) => storage[key],
      writeString: (key, value) async => storage[key] = value,
    );

    await store.save('alice', [
      {'userName': 'bob', 'lastMessage': '你好'},
    ]);

    expect(store.load('alice').single['userName'], 'bob');
    expect(store.load('charlie'), isEmpty);
  });

  testWidgets('cold start renders the local conversation before networking', (
    tester,
  ) async {
    final storage = <String, String>{};
    final store = ConversationSnapshotStore(
      readString: (key) => storage[key],
      writeString: (key, value) async => storage[key] = value,
    );
    GlobalUtil().userName = 'owner';
    await store.save('owner', [
      Chat(
        name: '本地好友',
        avatar: '',
        lastMessage: '本地会话摘要',
        time: '10:30',
        unreadCount: 2,
        userName: 'friend',
        updateTime: 1000,
      ).toCacheJson(),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Chatpage(
          chatList: const [],
          autoRefresh: false,
          conversationSnapshotStore: store,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('本地好友'), findsOneWidget);
    expect(find.text('本地会话摘要'), findsOneWidget);
    expect(find.text('暂无聊天会话'), findsNothing);
  });
}
