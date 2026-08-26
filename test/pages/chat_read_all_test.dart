import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/pages/mainPages/chatPage.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('断线时一键已读不会只清除本地红点', (tester) async {
    GlobalUtil().userName = 'reader';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Chatpage(
          autoRefresh: false,
          chatList: [
            Chat(
              name: 'Alice',
              avatar: '',
              lastMessage: 'hello',
              time: '10:00',
              unreadCount: 2,
              userName: 'alice',
              updateTime: 1,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('一键已读'));
    await tester.pump();

    expect(find.text('服务器未连接，暂时无法标记已读'), findsOneWidget);
    expect(find.byKey(const Key('chat_unread_badge_alice')), findsOneWidget);
    expect(find.byKey(const Key('chat_unread_summary')), findsOneWidget);
  });
}
