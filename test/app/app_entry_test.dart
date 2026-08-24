import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/main.dart';
import 'package:flutter_base/core/network/app_connection_monitor.dart';

void main() {
  testWidgets('应用只创建一个 MaterialApp 并显示登录页', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
  });

  test('已恢复的登录会话选择主界面作为启动路由', () {
    expect(appInitialRoute(true), '/mainWidget');
    expect(appInitialRoute(false), '/login');
  });

  testWidgets('断线和恢复时分别显示一次全局提示弹窗', (tester) async {
    final monitor = AppConnectionMonitor(
      backendProbe: () async => false,
      probeInterval: const Duration(hours: 1),
    );
    await tester.pumpWidget(
      MyApp(connectionMonitor: monitor, connectionNoticeDelay: Duration.zero),
    );
    await tester.pump();

    monitor.reportHttpUnavailable();
    expect(monitor.status, AppConnectionStatus.disconnected);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('连接已断开'), findsOneWidget);

    monitor.reportHttpReachable();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('连接已恢复'), findsOneWidget);
    expect(find.text('连接已断开'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    monitor.dispose();
  });

  testWidgets('后台挂起后恢复连接不会显示断开或恢复弹窗', (tester) async {
    final monitor = AppConnectionMonitor(
      backendProbe: () async => true,
      probeInterval: const Duration(hours: 1),
      resumeGracePeriod: const Duration(milliseconds: 30),
    );
    await tester.pumpWidget(
      MyApp(
        connectionMonitor: monitor,
        connectionNoticeDelay: const Duration(milliseconds: 10),
      ),
    );
    monitor.expectRealtimeConnection(true);
    monitor.reportRealtimeConnected();
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    monitor.reportRealtimeUnavailable();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('连接已断开'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    monitor.reportRealtimeConnected();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('连接已断开'), findsNothing);
    expect(find.text('连接已恢复'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    monitor.dispose();
  });
}
