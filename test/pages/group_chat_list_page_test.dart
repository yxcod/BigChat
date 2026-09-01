import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/pages/groupPages/groupChatListPage.dart';
import 'package:flutter_base/features/groups/data/group_data_cache.dart';
import 'package:flutter_base/model/groupInfoModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final groups = [
    GroupChat(
      groupId: 1,
      name: '产品体验群',
      avatar: '',
      previousAvatar: '',
      creatorId: 'me',
      description: '一起把体验做得更好',
    ),
    GroupChat(
      groupId: 2,
      name: '测试群',
      avatar: '',
      previousAvatar: '',
      creatorId: 'other',
      description: '今晚一起联调',
    ),
  ];

  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GroupChatListPage(
          initialGroups: groups,
          autoRefresh: false,
          currentUserName: 'me',
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('我的群聊页面按管理关系分组展示', (tester) async {
    await pumpPage(tester);

    expect(find.text('我的群聊'), findsOneWidget);
    expect(find.text('共 2 个群聊'), findsOneWidget);
    expect(find.byKey(const ValueKey('group_summary_card')), findsOneWidget);
    expect(find.text('我管理的  1'), findsOneWidget);
    expect(find.text('我加入的  1'), findsOneWidget);
    expect(find.text('群主'), findsOneWidget);
    expect(find.text('产品体验群'), findsOneWidget);
    expect(find.text('测试群'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('群聊搜索同时匹配名称和简介', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), '联调');
    await tester.pump();

    expect(find.text('产品体验群'), findsNothing);
    expect(find.text('测试群'), findsOneWidget);
    expect(find.byKey(const ValueKey('group_summary_card')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('冷启动优先展示本地群列表快照', (tester) async {
    final storage = <String, String>{};
    final cache = GroupDataCache(
      readString: (key) => storage[key],
      writeString: (key, value) async => storage[key] = value,
      deleteString: (key) async => storage.remove(key),
    );
    await cache.saveGroups('me', [
      GroupInfoModel(
        groupId: 3,
        groupName: '离线可见群',
        creatorId: 'me',
        description: '本地资料',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: GroupChatListPage(
          autoRefresh: false,
          currentUserName: 'me',
          groupDataCache: cache,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('离线可见群'), findsOneWidget);
    expect(find.text('共 1 个群聊'), findsOneWidget);
  });
}
