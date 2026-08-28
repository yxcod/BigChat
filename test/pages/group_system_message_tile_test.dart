import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_base/pages/groupPages/groupChatDialog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('member join message is compact and opens the member profile', (
    tester,
  ) async {
    var tapped = false;
    final message = Message(
      msgId: 1,
      content: '群主邀请新成员加入了群聊',
      isMe: false,
      time: '10:00',
      isRead: true,
      conversationId: '5',
      messageType: MessageType.system,
      groupSystemEvent: const GroupSystemEvent(
        kind: 'group_member_joined',
        userId: 'new-user',
        nickname: '新成员',
        inviterId: 'owner',
        inviterNickname: '群主',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: GroupSystemMessageTile(
            message: message,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('群主邀请新成员加入了群聊', findRichText: true), findsOneWidget);
    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });
}
