import '../../../utils/storageUtil.dart';
import '../domain/app_settings.dart';

typedef SettingsBoolReader = bool? Function(String key);
typedef SettingsStringReader = String? Function(String key);
typedef SettingsBoolWriter = Future<void> Function(String key, bool value);
typedef SettingsStringWriter = Future<void> Function(String key, String value);

class AppSettingsRepository {
  AppSettingsRepository({
    required String ownerId,
    SettingsBoolReader? readBool,
    SettingsStringReader? readString,
    SettingsBoolWriter? writeBool,
    SettingsStringWriter? writeString,
  }) : _ownerId = ownerId.trim().isEmpty ? 'device' : ownerId.trim(),
       _readBool = readBool,
       _readString = readString,
       _writeBool = writeBool,
       _writeString = writeString;

  final String _ownerId;
  final SettingsBoolReader? _readBool;
  final SettingsStringReader? _readString;
  final SettingsBoolWriter? _writeBool;
  final SettingsStringWriter? _writeString;

  String _key(String name) =>
      'app_settings_${Uri.encodeComponent(_ownerId)}_$name';

  Future<AppSettings> load() async {
    if (_readBool == null || _readString == null) await StorageUtil.init();
    return AppSettings(
      privacyMode: _getBool('privacy_mode') ?? false,
      locationEnabled: _getBool('location_enabled') ?? true,
      vibrationEnabled: _getBool('vibration_enabled') ?? true,
      bannerEnabled: _getBool('banner_enabled') ?? true,
      messageSoundEnabled: _getBool('message_sound_enabled') ?? true,
      messageSoundId:
          _getString('message_sound_id') ?? NotificationSound.systemDefaultId,
    );
  }

  Future<void> setPrivacyMode(bool value) => _setBool('privacy_mode', value);
  Future<void> setLocationEnabled(bool value) =>
      _setBool('location_enabled', value);
  Future<void> setVibrationEnabled(bool value) =>
      _setBool('vibration_enabled', value);
  Future<void> setBannerEnabled(bool value) =>
      _setBool('banner_enabled', value);
  Future<void> setMessageSoundEnabled(bool value) =>
      _setBool('message_sound_enabled', value);
  Future<void> setMessageSoundId(String value) =>
      _setString('message_sound_id', NotificationSound.byId(value).id);

  bool? _getBool(String name) =>
      _readBool?.call(_key(name)) ?? StorageUtil.getBool(_key(name));

  String? _getString(String name) =>
      _readString?.call(_key(name)) ?? StorageUtil.getString(_key(name));

  Future<void> _setBool(String name, bool value) async {
    if (_writeBool != null) {
      await _writeBool(_key(name), value);
      return;
    }
    await StorageUtil.setBool(_key(name), value);
  }

  Future<void> _setString(String name, String value) async {
    if (_writeString != null) {
      await _writeString(_key(name), value);
      return;
    }
    await StorageUtil.setString(_key(name), value);
  }
}
