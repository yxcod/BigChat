import 'package:flutter/material.dart';
import 'package:flutter_base/model/userInfoModel.dart';
import 'package:flutter_base/model/groupMemberModel.dart';
import 'package:flutter_base/pages/groupPages/groupChatSettingsPage.dart';
import 'package:flutter_base/shared/pages/app_text_editor_page.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GlobalUtil().userName = 'group-settings-user';
    GlobalUtil().userInfoModel = UserInfoModel(
      userName: 'group-settings-user',
      nickName: '我',
      avatar: '',
      signature: '',
      friendListData: const [],
    );
  });

  testWidgets('群资料文本入口使用独立编辑页面而不是输入弹窗', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: GroupChatSettingsPage(
          groupId: '10001',
          groupName: '测试群',
          loadRemoteData: false,
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('群聊名称'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('群聊名称'));
    await tester.pumpAndSettle();

    expect(find.byType(AppTextEditorPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('group_name_editor')), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('群介绍'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group_description_editor')), findsOneWidget);
  });

  testWidgets('群设置展示并保存群消息免打扰开关', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GroupChatSettingsPage(
          groupId: '10002',
          groupName: '静音群',
          loadRemoteData: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switchFinder = find.byKey(const ValueKey('group_mute_switch'));
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
  });

  testWidgets('群设置优先展示已缓存成员且群主权限不会降级', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GroupChatSettingsPage(
          groupId: '10003',
          groupName: '成员缓存群',
          loadRemoteData: false,
          groupMembers: [
            GroupMemberModel(
              groupId: 10003,
              userId: 'group-settings-user',
              groupNickName: '群主',
              role: 2,
            ),
            GroupMemberModel(
              groupId: 10003,
              userId: 'member-user',
              groupNickName: '成员',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('查看2名成员'), findsOneWidget);
    expect(find.text('群主'), findsWidgets);
    expect(find.text('成员'), findsOneWidget);
  });
}
