import 'package:flutter_base/features/settings/data/app_settings_repository.dart';
import 'package:flutter_base/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads defaults and persists settings for the current account',
    () async {
      final bools = <String, bool>{};
      final strings = <String, String>{};
      final repository = _repository('alice', bools, strings);

      final defaults = await repository.load();
      expect(defaults.privacyMode, isFalse);
      expect(defaults.locationEnabled, isTrue);
      expect(defaults.vibrationEnabled, isTrue);
      expect(defaults.bannerEnabled, isTrue);
      expect(defaults.messageSoundEnabled, isTrue);
      expect(defaults.messageSoundId, NotificationSound.systemDefaultId);

      await repository.setPrivacyMode(true);
      await repository.setLocationEnabled(false);
      await repository.setVibrationEnabled(false);
      await repository.setBannerEnabled(false);
      await repository.setMessageSoundEnabled(false);
      await repository.setMessageSoundId('glass');

      final restored = await repository.load();
      expect(restored.privacyMode, isTrue);
      expect(restored.locationEnabled, isFalse);
      expect(restored.vibrationEnabled, isFalse);
      expect(restored.bannerEnabled, isFalse);
      expect(restored.messageSoundEnabled, isFalse);
      expect(restored.messageSoundId, 'glass');
    },
  );

  test('keeps settings isolated between accounts', () async {
    final bools = <String, bool>{};
    final strings = <String, String>{};
    final alice = _repository('alice', bools, strings);
    final bob = _repository('bob', bools, strings);

    await alice.setPrivacyMode(true);

    expect((await alice.load()).privacyMode, isTrue);
    expect((await bob.load()).privacyMode, isFalse);
  });
}

AppSettingsRepository _repository(
  String ownerId,
  Map<String, bool> bools,
  Map<String, String> strings,
) {
  return AppSettingsRepository(
    ownerId: ownerId,
    readBool: (key) => bools[key],
    readString: (key) => strings[key],
    writeBool: (key, value) async {
      bools[key] = value;
    },
    writeString: (key, value) async {
      strings[key] = value;
    },
  );
}
