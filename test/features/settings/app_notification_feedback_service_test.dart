import 'package:flutter_base/features/chat/domain/chat_realtime_event.dart';
import 'package:flutter_base/features/settings/application/app_notification_feedback_service.dart';
import 'package:flutter_base/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'incoming message follows vibration sound and banner settings',
    () async {
      var vibrationCount = 0;
      final playedSounds = <String>[];
      final service = AppNotificationFeedbackService(
        loadSettings: () async => const AppSettings(
          vibrationEnabled: true,
          bannerEnabled: true,
          messageSoundEnabled: true,
          messageSoundId: 'glass',
        ),
        vibrate: () async => vibrationCount++,
        playSound: (soundId) async => playedSounds.add(soundId),
      );
      final event = ChatRealtimeEvent.parse({
        'type': 'message',
        'sendUserId': 'notification_sender_987',
        'msgContent': '你好',
        'msgType': 1,
      });

      final notice = await service.handle(event, appIsForeground: true);

      expect(vibrationCount, 1);
      expect(playedSounds, ['glass']);
      expect(notice?.body, '你好');
    },
  );

  test(
    'disabled feedback and active conversation produce no effects',
    () async {
      var vibrationCount = 0;
      var soundCount = 0;
      final service = AppNotificationFeedbackService(
        loadSettings: () async => const AppSettings(
          vibrationEnabled: false,
          bannerEnabled: false,
          messageSoundEnabled: false,
        ),
        vibrate: () async => vibrationCount++,
        playSound: (_) async => soundCount++,
      );
      final event = ChatRealtimeEvent.parse({
        'type': 'groupChat',
        'sendUserId': 'notification_sender_987',
        'groupId': 123456,
        'msgContent': 'photo.jpg',
        'msgType': 2,
      });

      final disabledNotice = await service.handle(event, appIsForeground: true);
      final activeNotice = await service.handle(
        event,
        appIsForeground: true,
        conversationIsActive: true,
      );

      expect(disabledNotice, isNull);
      expect(activeNotice, isNull);
      expect(vibrationCount, 0);
      expect(soundCount, 0);
    },
  );

  test('muted group skips vibration sound and banner', () async {
    var vibrationCount = 0;
    var soundCount = 0;
    final service = AppNotificationFeedbackService(
      loadSettings: () async => const AppSettings(
        vibrationEnabled: true,
        bannerEnabled: true,
        messageSoundEnabled: true,
      ),
      vibrate: () async => vibrationCount++,
      playSound: (_) async => soundCount++,
      isGroupMuted: (groupId) async => groupId == 123456,
    );
    final event = ChatRealtimeEvent.parse({
      'type': 'groupChat',
      'sendUserId': 'notification_sender_987',
      'groupId': 123456,
      'msgContent': '免打扰消息',
      'msgType': 1,
    });

    final notice = await service.handle(event, appIsForeground: true);

    expect(notice, isNull);
    expect(vibrationCount, 0);
    expect(soundCount, 0);
  });
}
