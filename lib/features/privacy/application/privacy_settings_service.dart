import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../utils/gloabl.dart';
import '../../../utils/storageUtil.dart';
import '../domain/privacy_settings.dart';

class PrivacySettingsService extends ChangeNotifier {
  PrivacySettingsService._();

  static final PrivacySettingsService instance = PrivacySettingsService._();

  PrivacySettings _settings = const PrivacySettings();
  String _ownerId = '';

  PrivacySettings get settings => _settings;
  bool get enabled => _settings.enabled;

  String _key(String name) =>
      'privacy_${Uri.encodeComponent(_ownerId.isEmpty ? 'device' : _ownerId)}_$name';

  Future<void> load({String? ownerId}) async {
    await StorageUtil.init();
    _ownerId = (ownerId ?? GlobalUtil().userName ?? '').trim();
    _settings = PrivacySettings(
      enabled: StorageUtil.getBool(_appSettingsKey('privacy_mode')) ?? false,
      readDestroySeconds:
          int.tryParse(StorageUtil.getString(_key('read_seconds')) ?? '') ?? 10,
      unreadDestroySeconds:
          int.tryParse(StorageUtil.getString(_key('unread_seconds')) ?? '') ??
          180,
      gestureSalt: StorageUtil.getString(_key('gesture_salt')) ?? '',
      gestureDigest: StorageUtil.getString(_key('gesture_digest')) ?? '',
    );
    // 旧版本只有开关、没有手势密码。升级后不能让这种不完整配置进入隐私模式。
    if (_settings.enabled && !_settings.hasGesturePassword) {
      _settings = _settings.copyWith(enabled: false);
      await StorageUtil.setBool(_appSettingsKey('privacy_mode'), false);
    }
    notifyListeners();
  }

  String _appSettingsKey(String name) =>
      'app_settings_${Uri.encodeComponent(_ownerId.isEmpty ? 'device' : _ownerId)}_$name';

  Future<void> setEnabled(bool value) async {
    _settings = _settings.copyWith(enabled: value);
    await StorageUtil.setBool(_appSettingsKey('privacy_mode'), value);
    notifyListeners();
  }

  Future<void> setDestroyDelays({
    required int readSeconds,
    required int unreadSeconds,
  }) async {
    _settings = _settings.copyWith(
      readDestroySeconds: readSeconds,
      unreadDestroySeconds: unreadSeconds,
    );
    await StorageUtil.setString(
      _key('read_seconds'),
      _settings.readDestroySeconds.toString(),
    );
    await StorageUtil.setString(
      _key('unread_seconds'),
      _settings.unreadDestroySeconds.toString(),
    );
    notifyListeners();
  }

  Future<void> setGesturePassword(List<int> pattern) async {
    if (pattern.length < 4) throw ArgumentError('手势密码至少连接4个点');
    final random = Random.secure();
    final salt = List<int>.generate(24, (_) => random.nextInt(256));
    final saltText = base64UrlEncode(salt);
    final digest = _digestPattern(saltText, pattern);
    await StorageUtil.setString(_key('gesture_salt'), saltText);
    await StorageUtil.setString(_key('gesture_digest'), digest);
    _settings = _settings.copyWith(
      gestureSalt: saltText,
      gestureDigest: digest,
    );
    notifyListeners();
  }

  bool verifyGesture(List<int> pattern) {
    if (!_settings.hasGesturePassword) return false;
    return _constantTimeEquals(
      _settings.gestureDigest,
      _digestPattern(_settings.gestureSalt, pattern),
    );
  }

  // 多轮、加盐的本地摘要。这里只保存不可逆结果，不保存手势明文。
  String _digestPattern(String salt, List<int> pattern) {
    var state = 0xcbf29ce484222325;
    var input = utf8.encode('$salt:${pattern.join('-')}');
    for (var round = 0; round < 12000; round++) {
      for (final byte in input) {
        state ^= byte;
        state = (state * 0x100000001b3) & 0x7fffffffffffffff;
        state ^= state >> 29;
      }
      input = utf8.encode('$state:$salt:$round');
    }
    return state.toRadixString(16).padLeft(16, '0');
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }
}
