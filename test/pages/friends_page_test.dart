import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/pages/mainPages/friendsPage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final friends = [
    Friend(
      userName: 'linxia',
      remark: '',
      name: '林夏',
      nickName: '林夏',
      avatar: '👤',
      previousAvatar: '',
      signature: '今天也要保持好心情',
      time: '',
      isOnline: true,
    ),
    Friend(
      userName: 'yexiang',
      remark: '',
      name: '叶翔',
      nickName: '叶翔',
      avatar: '👤',
      previousAvatar: '',
      signature: '保持热爱，奔赴山海',
      time: '',
      isOnline: false,
    ),
  ];

  Future<void> pumpFriendsPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Friendspage(friendListDate: friends, autoRefresh: false),
      ),
    );
    await tester.pump();
  }

  testWidgets('好友页使用快捷入口、在线优先列表和字母索引', (tester) async {
    await pumpFriendsPage(tester);

    expect(find.text('好友'), findsNWidgets(2));
    expect(find.text('新的朋友'), findsOneWidget);
    expect(find.text('我的群聊'), findsOneWidget);
    expect(find.text('添加好友'), findsOneWidget);
    expect(
      tester.getCenter(find.text('添加好友')).dx,
      lessThan(tester.getCenter(find.text('我的群聊')).dx),
    );
    expect(find.text('在线优先'), findsOneWidget);
    expect(find.byKey(const ValueKey('friends_shortcut_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('friends_list_surface')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('friends_alphabet_index')),
      findsOneWidget,
    );
    expect(find.text('林夏'), findsOneWidget);
    expect(find.text('叶翔'), findsOneWidget);
    expect(find.text('动态'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('右上角菜单只保留创建群聊', (tester) async {
    await pumpFriendsPage(tester);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();

    expect(find.text('创建群聊'), findsOneWidget);
    expect(find.text('添加好友'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('搜索时隐藏快捷入口并只显示匹配好友', (tester) async {
    await pumpFriendsPage(tester);

    await tester.enterText(find.byType(TextField), '叶');
    await tester.pump();

    expect(find.byKey(const ValueKey('friends_shortcut_card')), findsNothing);
    expect(find.byKey(const ValueKey('friends_alphabet_index')), findsNothing);
    expect(find.text('林夏'), findsNothing);
    expect(find.text('叶翔'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
