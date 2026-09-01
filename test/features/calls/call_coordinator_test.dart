import 'package:flutter/material.dart';
import 'package:flutter_base/features/calls/application/call_coordinator.dart';
import 'package:flutter_base/utils/GlobalNavigatorKey.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coordinator = CallCoordinator.instance;

  tearDown(() {
    coordinator.dispose();
    coordinator.activeSession.value = null;
    GlobalUtil().userName = null;
    GlobalUtil().token = null;
  });

  testWidgets('foreground invite schedules a frame and opens immediately', (
    tester,
  ) async {
    final observer = _RouteObserver();
    GlobalUtil().userName = 'bob';
    GlobalUtil().token = 'test-token';
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: GlobalNavigatorKey.navigatorKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('chat')),
      ),
    );
    await tester.pumpAndSettle();

    coordinator.handleExternalInvite({
      'eventType': 'videoCallInvite',
      'callId': 'private_alice_1',
      'channelName': 'quanxin_private_alice_1',
      'senderId': 'alice',
      'senderName': 'Alice',
    });

    await tester.pump();
    expect(observer.lastRouteName, '/callLobby');

    coordinator.dispose();
    coordinator.activeSession.value = null;
  });
}

class _RouteObserver extends NavigatorObserver {
  String? lastRouteName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    lastRouteName = route.settings.name;
    super.didPush(route, previousRoute);
  }
}
