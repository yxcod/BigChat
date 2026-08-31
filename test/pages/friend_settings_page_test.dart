import 'package:flutter/material.dart';
import 'package:flutter_base/model/userInfoModel.dart';
import 'package:flutter_base/pages/friendManage/editFriendRemarkPage.dart';
import 'package:flutter_base/pages/friendManage/friendSettingsPage.dart';
import 'package:flutter_base/features/reporting/presentation/user_report_page.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('remark uses a full page editor and updates without a dialog', (
    tester,
  ) async {
    final global = GlobalUtil();
    global.userName = 'me';
    global.userInfoModel = UserInfoModel(
      userName: 'me',
      nickName: '我',
      avatar: '',
      signature: '',
      friendListData: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FriendSettingsPage(
          friendData: const {
            'userName': 'friend',
            'nickname': '小李',
            'remark': '旧备注',
          },
          remarkUpdater: (current, friend, remark) async {
            expect(current, 'me');
            expect(friend, 'friend');
            expect(remark, '新备注');
            return {'code': '100'};
          },
        ),
      ),
    );

    final tileRect = tester.getRect(
      find.byKey(const Key('friend_remark_tile')),
    );
    final arrowRect = tester.getRect(
      find.byKey(const Key('friend_remark_arrow')),
    );
    expect(arrowRect.right, closeTo(tileRect.right - 16, 0.1));

    await tester.tap(find.byKey(const Key('friend_remark_tile')));
    await tester.pumpAndSettle();

    expect(find.byType(EditFriendRemarkPage), findsOneWidget);
    expect(find.text('设置备注'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.enterText(find.byKey(const Key('friend_remark_field')), '新备注');
    await tester.tap(find.byKey(const Key('friend_remark_complete_button')));
    await tester.pumpAndSettle();

    expect(find.byType(FriendSettingsPage), findsOneWidget);
    expect(find.text('新备注'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing friend actions use the compact grouped layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FriendSettingsPage(
          friendData: const {'userName': 'friend', 'remark': ''},
        ),
      ),
    );

    final actionsCard = find.byKey(const Key('friend_settings_actions_card'));
    expect(actionsCard, findsOneWidget);
    expect(
      find.descendant(of: actionsCard, matching: find.text('删除聊天记录')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: actionsCard, matching: find.text('加入黑名单')),
      findsOneWidget,
    );
    expect(find.byType(Switch), findsNothing);

    final friendText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('delete_friend_button')),
        matching: find.text('删除好友'),
      ),
    );
    expect(friendText.style?.color, isNotNull);
    expect(find.text('被骚扰了？举报该用户'), findsOneWidget);

    await tester.tap(find.byKey(const Key('delete_chat_history_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('不会影响对方保存的聊天记录'), findsOneWidget);
    expect(find.textContaining('双方都删除后'), findsOneWidget);
  });

  testWidgets('report action opens the UI-only report page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FriendSettingsPage(
          friendData: {'userName': 'friend', 'nickname': '好友昵称', 'remark': ''},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('report_user_button')));
    await tester.pumpAndSettle();
    expect(find.byType(UserReportPage), findsOneWidget);
    expect(find.text('账号：friend'), findsOneWidget);
  });
}
