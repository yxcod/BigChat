import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_colors.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/pages/mainPages/chatPage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('聊天首页展示未读定位、在线状态和红色徽标', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Chatpage(
          autoRefresh: false,
          chatList: [
            Chat(
              name: '张威',
              avatar: '',
              lastMessage: '今晚一起吃饭吗？',
              time: '10:42',
              unreadCount: 2,
              userName: 'zhangwei',
              isOnline: true,
              updateTime: 200,
            ),
            Chat(
              name: '测试群 (12)',
              avatar: '',
              lastMessage: '文件已经上传好了',
              time: '09:36',
              unreadCount: 3,
              userName: '12',
              isGroup: true,
              lastSenderName: '叶翔',
              updateTime: 100,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('聊天'), findsOneWidget);
    expect(find.text('搜索聊天记录'), findsOneWidget);
    expect(find.byKey(const Key('chat_create_group_button')), findsOneWidget);
    expect(find.byKey(const Key('chat_unread_summary')), findsOneWidget);
    expect(find.text('5 条未读消息'), findsOneWidget);
    expect(find.text('快速定位'), findsOneWidget);
    expect(find.text('今晚一起吃饭吗？'), findsOneWidget);
    expect(find.text('叶翔：文件已经上传好了'), findsOneWidget);
    expect(find.byKey(const Key('chat_online_zhangwei')), findsOneWidget);

    final unreadBadge = tester.widget<Container>(
      find.byKey(const Key('chat_unread_badge_zhangwei')),
    );
    final decoration = unreadBadge.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.danger);
    expect(tester.takeException(), isNull);
  });
}
