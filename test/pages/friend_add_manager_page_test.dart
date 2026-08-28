import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/model/friendRequestModel.dart';
import 'package:flutter_base/pages/friendManage/friendAddManagerPage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('最近消息可以解析申请方收到的拒绝状态', () {
    final message = RecentFriendModel.fromJSON({
      'id': 88,
      'fromUserId': 'sender',
      'toUserId': 'receiver',
      'direction': 'outgoing',
      'userName': 'receiver',
      'nickName': '接收方',
      'status': 2,
      'updateTime': 1787654321000,
    }, currentUserName: 'sender');

    expect(message.requestId, 88);
    expect(message.status, RequestStatus.rejected);
    expect(message.direction, FriendRequestDirection.outgoing);
    expect(message.eventKey, '88:rejected:1787654321000');
  });

  testWidgets('新的朋友页面分开展示待处理申请和最近消息', (tester) async {
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
    expect(find.text('拒绝'), findsOneWidget);
    expect(find.text('最近消息'), findsOneWidget);
    expect(find.byKey(const ValueKey('recent_friends_card')), findsOneWidget);
    expect(find.text('安然'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('最近消息显示申请方被拒绝记录', (tester) async {
    final recent = RecentFriendModel(
      requestId: 303,
      userName: 'rejector',
      nickName: '拒绝方',
      addTime: DateTime.now().millisecondsSinceEpoch,
      status: RequestStatus.rejected,
      direction: FriendRequestDirection.outgoing,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FriendAddManagerPage(
          initialRecentFriends: [recent],
          autoLoad: false,
        ),
      ),
    );

    expect(find.text('最近消息'), findsOneWidget);
    expect(find.text('对方拒绝了你的好友申请 · 刚刚'), findsOneWidget);
    expect(find.text('已拒绝'), findsOneWidget);
  });

  testWidgets('窄屏下拒绝说明与状态标签保持间距且无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final recent = RecentFriendModel(
      requestId: 304,
      userName: 'long-name-rejector',
      nickName: '这是一个较长的好友昵称',
      addTime: DateTime.now()
          .subtract(const Duration(hours: 16))
          .millisecondsSinceEpoch,
      status: RequestStatus.rejected,
      direction: FriendRequestDirection.incoming,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FriendAddManagerPage(
          initialRecentFriends: [recent],
          autoLoad: false,
        ),
      ),
    );

    expect(find.text('已拒绝'), findsOneWidget);
    expect(find.textContaining('你已拒绝对方的好友申请'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('发送方的待处理申请显示为待验证', (tester) async {
    final request = FriendRequestModel(
      requestId: 101,
      userName: 'receiver',
      nickName: '接收方',
      verificationMessage: '你好',
      requestTime: DateTime.now(),
      direction: FriendRequestDirection.outgoing,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FriendAddManagerPage(initialRequests: [request], autoLoad: false),
      ),
    );

    expect(find.text('待验证'), findsOneWidget);
  });

  testWidgets('已过期申请可以向右滑动删除', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var deleted = false;
    final request = FriendRequestModel(
      requestId: 202,
      userName: 'expired-user',
      nickName: '过期申请',
      verificationMessage: '三天前的申请',
      requestTime: DateTime.now().subtract(const Duration(days: 4)),
      status: RequestStatus.expired,
      direction: FriendRequestDirection.outgoing,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: FriendAddManagerPage(
          initialRequests: [request],
          autoLoad: false,
          deleteExpiredRequest: (_) async {
            deleted = true;
            return true;
          },
        ),
      ),
    );

    final expiredCell = find.byKey(
      const ValueKey('expired_friend_request_202'),
    );
    expect(expiredCell, findsOneWidget);
    await tester.drag(expiredCell, const Offset(320, 0));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(find.text('过期申请'), findsNothing);
  });
}
