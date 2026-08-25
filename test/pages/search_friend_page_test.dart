import 'package:flutter/material.dart';
import 'package:flutter_base/model/friendInfoModel.dart';
import 'package:flutter_base/model/userInfoModel.dart';
import 'package:flutter_base/pages/friendManage/searchFriendPage.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search result uses a compact public profile card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SearchFriendPage(
          userLoader: (userName) async => UserInfoModel(
            userName: userName,
            nickName: '测试用户',
            avatar: '',
            signature: '签名',
            friendListData: const [],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '13800138000');
    await tester.tap(find.text('搜索'));
    await tester.pump();

    final card = find.byKey(const Key('search_friend_result_card'));
    expect(card, findsOneWidget);
    expect(tester.getSize(card).height, lessThan(220));
    expect(tester.getSize(card).height, greaterThanOrEqualTo(140));
    expect(find.text('仅会展示对方公开的基本资料'), findsOneWidget);
  });

  testWidgets('existing friend is marked as added and cannot be added again', (
    tester,
  ) async {
    GlobalUtil().userInfoModel = UserInfoModel(
      userName: 'me',
      nickName: '我',
      avatar: '',
      signature: '',
      friendListData: [
        FriendInfoModel(
          userName: '18699998888',
          nickName: '已添加用户',
          remarks: '',
          avatar: '',
          signature: '',
          isOnline: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SearchFriendPage(
          userLoader: (userName) async => UserInfoModel(
            userName: userName,
            nickName: '已添加用户',
            avatar: '',
            signature: '',
            friendListData: const [],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '18699998888');
    await tester.tap(find.text('搜索'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search_friend_added_status')), findsOneWidget);
    expect(find.text('已添加'), findsOneWidget);
    expect(find.byKey(const Key('search_friend_add_button')), findsNothing);
  });

  testWidgets('tapping account card opens the profile instead of adding', (
    tester,
  ) async {
    GlobalUtil().userInfoModel = UserInfoModel(
      userName: 'me',
      nickName: '我',
      avatar: '',
      signature: '',
      friendListData: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SearchFriendPage(
          userLoader: (userName) async => UserInfoModel(
            userName: userName,
            nickName: '陌生用户',
            avatar: '',
            signature: '',
            friendListData: const [],
          ),
          profileBuilder: (userData) =>
              const Scaffold(body: Center(child: Text('陌生人资料页'))),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '13900139000');
    await tester.tap(find.text('搜索'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('search_friend_result_card')));
    await tester.pumpAndSettle();

    expect(find.text('陌生人资料页'), findsOneWidget);
  });
}
