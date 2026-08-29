import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_colors.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/features/groups/application/group_notification_settings_service.dart';
import 'package:flutter_base/pages/mainPages/chatPage.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(find.text('已收到 5 条新消息'), findsOneWidget);
    expect(find.text('一键已读'), findsOneWidget);
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

  testWidgets('免打扰群只显示灰点且不计入红色未读数', (tester) async {
    SharedPreferences.setMockInitialValues({});
    GlobalUtil().userName = 'muted-chat-ui-owner';
    final settings = GroupNotificationSettingsService.instance;
    await settings.load(ownerId: 'muted-chat-ui-owner');
    await settings.setMuted(12001, true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Chatpage(
          autoRefresh: false,
          chatList: [
            Chat(
              name: '免打扰群',
              avatar: '',
              lastMessage: '有一条新消息',
              time: '11:30',
              unreadCount: 4,
              userName: '12001',
              isGroup: true,
              updateTime: 300,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('chat_muted_unread_dot_12001')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('chat_unread_badge_12001')), findsNothing);
    expect(find.byKey(const Key('chat_unread_summary')), findsNothing);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('@我的群会话使用独立颜色摘要', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Chatpage(
          autoRefresh: false,
          chatList: [
            Chat(
              name: '测试群',
              avatar: '',
              lastMessage: '@叶翔 提醒信息',
              time: '10:40',
              unreadCount: 1,
              userName: '12002',
              isGroup: true,
              lastSenderName: '王瑞',
              mentionedMe: true,
              updateTime: 400,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('[有人@我]'), findsOneWidget);
    expect(find.textContaining('王瑞：@叶翔 提醒信息'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
