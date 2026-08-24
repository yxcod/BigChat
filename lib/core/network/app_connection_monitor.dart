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
    this.resumeGracePeriod = const Duration(seconds: 6),
  }) : _backendProbe = backendProbe ?? _defaultBackendProbe;

  static final AppConnectionMonitor instance = AppConnectionMonitor();

  final BackendProbe _backendProbe;
  final Duration probeInterval;
  final Duration resumeGracePeriod;
  final Set<VoidCallback> _backendReachableListeners = {};

  AppConnectionStatus _status = AppConnectionStatus.unknown;
  AppConnectionStatus get status => _status;

  bool _realtimeExpected = false;
  bool _realtimeConnected = false;
  bool _probeInProgress = false;
  bool _appActive = true;
  DateTime? _ignoreFailuresUntil;
  Timer? _probeTimer;
  Timer? _resumeGraceTimer;

  bool get isAppActive => _appActive;

  bool get _failureReportsSuppressed {
    if (!_appActive) return true;
    final ignoreUntil = _ignoreFailuresUntil;
    return ignoreUntil != null && DateTime.now().isBefore(ignoreUntil);
  }

  void setAppActive(bool active) {
    if (!active) {
      _appActive = false;
      _ignoreFailuresUntil = null;
      _resumeGraceTimer?.cancel();
      _resumeGraceTimer = null;
      _stopProbing();
      return;
    }

    _appActive = true;
    _resumeGraceTimer?.cancel();
    _status = AppConnectionStatus.unknown;
    _ignoreFailuresUntil = DateTime.now().add(resumeGracePeriod);
    _resumeGraceTimer = Timer(resumeGracePeriod, () async {
      _resumeGraceTimer = null;
      _ignoreFailuresUntil = null;
      await checkNow();
      if (_appActive && _status == AppConnectionStatus.disconnected) {
        _startProbing();
      }
    });
  }

  void expectRealtimeConnection(bool expected) {
    _realtimeExpected = expected;
    if (!expected) {
      _realtimeConnected = false;
    }
  }

  void reportRealtimeConnected() {
    _realtimeExpected = true;
    _realtimeConnected = true;
    _ignoreFailuresUntil = null;
    _resumeGraceTimer?.cancel();
    _resumeGraceTimer = null;
    _setStatus(AppConnectionStatus.connected);
  }

  void reportRealtimeUnavailable() {
    if (!_realtimeExpected) {
      return;
    }
    _realtimeConnected = false;
    if (_failureReportsSuppressed) return;
    _setStatus(AppConnectionStatus.disconnected);
  }

  void reportHttpReachable() {
    if (!_realtimeExpected || _realtimeConnected) {
      _setStatus(AppConnectionStatus.connected);
    }
  }

  void reportHttpUnavailable() {
    if (_realtimeConnected || _failureReportsSuppressed) {
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
    if (!_appActive || _probeInProgress) {
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
    if (!_appActive ||
        _failureReportsSuppressed ||
        _probeTimer?.isActive == true) {
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
    _resumeGraceTimer?.cancel();
    _resumeGraceTimer = null;
    _status = AppConnectionStatus.unknown;
    _realtimeExpected = false;
    _realtimeConnected = false;
    _probeInProgress = false;
    _appActive = true;
    _ignoreFailuresUntil = null;
  }

  @override
  void dispose() {
    _stopProbing();
    _resumeGraceTimer?.cancel();
    _backendReachableListeners.clear();
    super.dispose();
  }
}
