import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

enum AppConnectionStatus { unknown, connected, disconnected }

typedef BackendProbe = Future<bool> Function();

class AppConnectionMonitor extends ChangeNotifier {
  AppConnectionMonitor({
    BackendProbe? backendProbe,
    this.probeInterval = const Duration(seconds: 4),
  }) : _backendProbe = backendProbe ?? _defaultBackendProbe;

  static final AppConnectionMonitor instance = AppConnectionMonitor();

  final BackendProbe _backendProbe;
  final Duration probeInterval;
  final Set<VoidCallback> _backendReachableListeners = {};

  AppConnectionStatus _status = AppConnectionStatus.unknown;
  AppConnectionStatus get status => _status;

  bool _realtimeExpected = false;
  bool _realtimeConnected = false;
  bool _probeInProgress = false;
  Timer? _probeTimer;

  void expectRealtimeConnection(bool expected) {
    _realtimeExpected = expected;
    if (!expected) {
      _realtimeConnected = false;
    }
  }

  void reportRealtimeConnected() {
    _realtimeExpected = true;
    _realtimeConnected = true;
    _setStatus(AppConnectionStatus.connected);
  }

  void reportRealtimeUnavailable() {
    if (!_realtimeExpected) {
      return;
    }
    _realtimeConnected = false;
    _setStatus(AppConnectionStatus.disconnected);
  }

  void reportHttpReachable() {
    if (!_realtimeExpected || _realtimeConnected) {
      _setStatus(AppConnectionStatus.connected);
    }
  }

  void reportHttpUnavailable() {
    if (_realtimeConnected) {
      return;
    }
    _setStatus(AppConnectionStatus.disconnected);
  }

  void addBackendReachableListener(VoidCallback listener) {
    _backendReachableListeners.add(listener);
  }

  void removeBackendReachableListener(VoidCallback listener) {
    _backendReachableListeners.remove(listener);
  }

  Future<bool> checkNow() async {
    if (_probeInProgress) {
      return false;
    }
    _probeInProgress = true;
    try {
      final reachable = await _backendProbe();
      if (reachable) {
        reportHttpReachable();
        for (final listener in List<VoidCallback>.of(
          _backendReachableListeners,
        )) {
          listener();
        }
      } else {
        reportHttpUnavailable();
      }
      return reachable;
    } finally {
      _probeInProgress = false;
    }
  }

  void _setStatus(AppConnectionStatus nextStatus) {
    if (_status == nextStatus) {
      return;
    }
    _status = nextStatus;
    if (nextStatus == AppConnectionStatus.disconnected) {
      _startProbing();
    } else {
      _stopProbing();
    }
    notifyListeners();
  }

  void _startProbing() {
    if (_probeTimer?.isActive == true) {
      return;
    }
    _probeTimer = Timer.periodic(probeInterval, (_) => unawaited(checkNow()));
  }

  void _stopProbing() {
    _probeTimer?.cancel();
    _probeTimer = null;
  }

  static Future<bool> _defaultBackendProbe() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final request = await client
          .getUrl(Uri.parse(AppConfig.apiBaseUrl))
          .timeout(const Duration(seconds: 4));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      await response.drain<void>().timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _stopProbing();
    _status = AppConnectionStatus.unknown;
    _realtimeExpected = false;
    _realtimeConnected = false;
    _probeInProgress = false;
  }

  @override
  void dispose() {
    _stopProbing();
    _backendReachableListeners.clear();
    super.dispose();
  }
}
