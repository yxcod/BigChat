import 'package:flutter_base/features/groups/application/group_notification_settings_service.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('群免打扰按账号和群持久化且互不影响', () async {
    SharedPreferences.setMockInitialValues({});
    GlobalUtil().userName = 'mute-owner-a';

    final service = GroupNotificationSettingsService();
    await service.load(ownerId: 'mute-owner-a');
    await service.setMuted(10001, true);

    final restored = GroupNotificationSettingsService();
    await restored.load(ownerId: 'mute-owner-a');
    expect(restored.isMuted(10001), isTrue);
    expect(restored.isMuted(10002), isFalse);

    await restored.load(ownerId: 'mute-owner-b');
    expect(restored.isMuted(10001), isFalse);
  });
}
