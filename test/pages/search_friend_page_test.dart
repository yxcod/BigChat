import 'package:flutter/material.dart';
import 'package:flutter_base/model/userInfoModel.dart';
import 'package:flutter_base/pages/friendManage/searchFriendPage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('search result card wraps only its account content', (
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
    expect(tester.getSize(card).height, lessThan(100));
    expect(tester.getSize(card).height, greaterThanOrEqualTo(60));
  });
}
