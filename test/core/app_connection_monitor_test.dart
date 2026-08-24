import 'package:flutter_base/core/network/app_connection_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTTP and realtime connection transitions are coordinated', () {
    final monitor = AppConnectionMonitor(
      backendProbe: () async => false,
      probeInterval: const Duration(hours: 1),
    );
    final statuses = <AppConnectionStatus>[];
    monitor.addListener(() => statuses.add(monitor.status));

    monitor.reportHttpUnavailable();
    monitor.reportHttpUnavailable();
    monitor.reportHttpReachable();
    monitor.expectRealtimeConnection(true);
    monitor.reportRealtimeUnavailable();
    monitor.reportHttpReachable();
    monitor.reportRealtimeConnected();

    expect(statuses, [
      AppConnectionStatus.disconnected,
      AppConnectionStatus.connected,
      AppConnectionStatus.disconnected,
      AppConnectionStatus.connected,
    ]);
    monitor.dispose();
  });

  test(
    'background suspension and resume grace do not report a false outage',
    () async {
      var probeCount = 0;
      final monitor = AppConnectionMonitor(
        backendProbe: () async {
          probeCount++;
          return false;
        },
        probeInterval: const Duration(hours: 1),
        resumeGracePeriod: const Duration(milliseconds: 30),
      );
      monitor.expectRealtimeConnection(true);
      monitor.reportRealtimeConnected();

      monitor.setAppActive(false);
      monitor.reportRealtimeUnavailable();
      monitor.reportHttpUnavailable();
      expect(monitor.status, AppConnectionStatus.connected);
      expect(probeCount, 0);

      monitor.setAppActive(true);
      monitor.reportRealtimeUnavailable();
      expect(monitor.status, isNot(AppConnectionStatus.disconnected));

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(probeCount, 1);
      expect(monitor.status, AppConnectionStatus.disconnected);
      monitor.dispose();
    },
  );
}
