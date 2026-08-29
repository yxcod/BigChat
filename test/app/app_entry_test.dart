import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/main.dart';
import 'package:flutter_base/core/network/app_connection_monitor.dart';
import 'package:flutter_base/features/privacy/presentation/calculator_decoy_page.dart';
import 'package:flutter_base/features/privacy/presentation/gesture_pattern_pad.dart';
import 'package:flutter_base/features/privacy/presentation/privacy_unlock_page.dart';

Future<void> drawPrivacyGesture(WidgetTester tester) async {
  final pad = find.byType(GesturePatternPad);
  final rect = tester.getRect(pad);
  Offset point(int index) => Offset(
    rect.left + rect.width * ((index % 3) + .5) / 3,
    rect.top + rect.height * ((index ~/ 3) + .5) / 3,
  );
  final gesture = await tester.startGesture(point(0));
  for (final index in const [3, 6, 7]) {
    await gesture.moveTo(point(index));
  }
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('应用只创建一个 MaterialApp 并显示登录页', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
  });

  testWidgets('普通展示文字支持长按选择和系统复制工具栏', (tester) async {
    await tester.pumpWidget(const MyApp(initialRoute: '/login'));
    await tester.pump();

    await tester.longPress(find.text('全信'));
    await tester.pumpAndSettle();

    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
  });

  test('已恢复的登录会话选择主界面作为启动路由', () {
    expect(appInitialRoute(true), '/mainWidget');
    expect(appInitialRoute(false), '/login');
  });

  test('冷启动仅在已登录、隐私模式开启且已设置手势时强制锁定', () {
    expect(
      appRequiresPrivacyUnlock(
        hasAuthenticatedSession: true,
        privacyEnabled: true,
        hasGesturePassword: true,
      ),
      isTrue,
    );
    expect(
      appRequiresPrivacyUnlock(
        hasAuthenticatedSession: false,
        privacyEnabled: true,
        hasGesturePassword: true,
      ),
      isFalse,
    );
    expect(
      appRequiresPrivacyUnlock(
        hasAuthenticatedSession: true,
        privacyEnabled: false,
        hasGesturePassword: true,
      ),
      isFalse,
    );
  });

  testWidgets('冷启动隐私锁在首帧覆盖应用内容', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MyApp(initialRoute: '/login', initiallyPrivacyLocked: true),
    );
    await tester.pump();

    expect(find.byType(PrivacyUnlockPage), findsOneWidget);
    expect(find.text('隐私模式已锁定'), findsOneWidget);
    expect(find.text('登录'), findsNothing);
  });

  testWidgets('手势错误直接进入计算器且下次恢复重新要求手势', (tester) async {
    final monitor = AppConnectionMonitor(
      backendProbe: () async => true,
      probeInterval: const Duration(hours: 1),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MyApp(
        initialRoute: '/login',
        initiallyPrivacyLocked: true,
        connectionMonitor: monitor,
        privacyLockRequired: () => true,
        privacyGestureVerifier: (_) => false,
      ),
    );
    await tester.pump();

    await drawPrivacyGesture(tester);
    expect(find.byType(CalculatorDecoyPage), findsOneWidget);
    expect(find.textContaining('手势错误'), findsNothing);
    expect(find.text('登录'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(PrivacyUnlockPage), findsOneWidget);
    expect(find.byType(CalculatorDecoyPage), findsNothing);
    expect(find.text('登录'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await drawPrivacyGesture(tester);
    expect(find.byType(CalculatorDecoyPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    monitor.dispose();
  });

  testWidgets('解锁后再次进入后台会在业务页暴露前切换到手势锁', (tester) async {
    final monitor = AppConnectionMonitor(
      backendProbe: () async => true,
      probeInterval: const Duration(hours: 1),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MyApp(
        initialRoute: '/login',
        initiallyPrivacyLocked: true,
        connectionMonitor: monitor,
        privacyLockRequired: () => true,
        privacyGestureVerifier: (_) => true,
      ),
    );
    await tester.pump();

    await drawPrivacyGesture(tester);
    expect(find.byType(PrivacyUnlockPage), findsNothing);
    expect(find.text('登录'), findsWidgets);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byType(PrivacyUnlockPage), findsOneWidget);
    expect(find.text('登录'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(PrivacyUnlockPage), findsOneWidget);
    expect(find.text('登录'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    monitor.dispose();
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
