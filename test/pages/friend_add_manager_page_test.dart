import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/model/friendRequestModel.dart';
import 'package:flutter_base/pages/friendManage/friendAddManagerPage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('新的朋友页面分开展示待处理申请和最近添加', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final request = FriendRequestModel(
      requestId: null,
      userName: 'linxia',
      nickName: '林夏',
      verificationMessage: '你好，我们在测试群里聊过',
      requestTime: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    final recent = RecentFriendModel(
      userName: 'anran',
      nickName: '安然',
      addTime: DateTime.now().millisecondsSinceEpoch,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FriendAddManagerPage(
          initialRequests: [request],
          initialRecentFriends: [recent],
          autoLoad: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('新的朋友'), findsOneWidget);
    expect(find.text('待处理  1'), findsOneWidget);
    expect(find.byKey(const ValueKey('friend_request_card')), findsOneWidget);
    expect(find.text('同意'), findsOneWidget);
    expect(find.text('忽略'), findsOneWidget);
    expect(find.text('最近添加'), findsOneWidget);
    expect(find.byKey(const ValueKey('recent_friends_card')), findsOneWidget);
    expect(find.text('安然'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
