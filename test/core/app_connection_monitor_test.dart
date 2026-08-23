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
}
