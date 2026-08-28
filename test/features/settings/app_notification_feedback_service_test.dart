import 'package:flutter_base/features/chat/domain/chat_realtime_event.dart';
import 'package:flutter_base/features/settings/application/app_notification_feedback_service.dart';
import 'package:flutter_base/features/settings/domain/app_settings.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

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

  test('group mention notification is marked as at-me', () async {
    GlobalUtil().userName = 'receiver_100';
    final service = AppNotificationFeedbackService(
      loadSettings: () async => const AppSettings(
        vibrationEnabled: false,
        bannerEnabled: true,
        messageSoundEnabled: false,
      ),
      isGroupMuted: (_) async => false,
    );
    final event = ChatRealtimeEvent.parse({
      'type': 'groupChat',
      'sendUserId': 'sender_200',
      'groupId': 123456,
      'msgContent': '@小明 你好',
      'msgType': 1,
      'extendInfo': const MessageExtensions(
        mentions: [MessageMention(userId: 'receiver_100', label: '小明')],
      ).encode(),
    });

    final notice = await service.handle(event, appIsForeground: true);

    expect(notice?.body, '[@我] @小明 你好');
  });

  test(
    'read receipts and own echoed messages never trigger feedback',
    () async {
      GlobalUtil().userName = 'sender_200';
      var feedbackCount = 0;
      final service = AppNotificationFeedbackService(
        loadSettings: () async => const AppSettings(
          vibrationEnabled: true,
          bannerEnabled: true,
          messageSoundEnabled: true,
        ),
        vibrate: () async => feedbackCount++,
        playSound: (_) async => feedbackCount++,
      );

      final receipt = ChatRealtimeEvent.parse({
        'type': 'read_ack',
        'msgId': 99,
      });
      final ownEcho = ChatRealtimeEvent.parse({
        'type': 'message',
        'sendUserId': 'sender_200',
        'msgId': 99,
        'msgContent': '自己的消息',
      });

      expect(await service.handle(receipt, appIsForeground: true), isNull);
      expect(await service.handle(ownEcho, appIsForeground: true), isNull);
      expect(feedbackCount, 0);
    },
  );

  test('incoming friend request follows notification settings', () async {
    GlobalUtil().userName = 'receiver_100';
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
    );
    final event = ChatRealtimeEvent.parse({
      'type': 'friendRequestUpdated',
      'action': 'created',
      'fromUserId': 'sender_200',
      'toUserId': 'receiver_100',
      'fromNickName': '测试用户',
      'applyMsg': '我是新同学',
    });

    final notice = await service.handle(event, appIsForeground: true);

    expect(notice?.title, '新的好友申请');
    expect(notice?.body, '测试用户：我是新同学');
    expect(vibrationCount, 1);
    expect(soundCount, 1);
  });

  test('rejected friend request notifies the applicant', () async {
    GlobalUtil().userName = 'sender_200';
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
    );
    final event = ChatRealtimeEvent.parse({
      'type': 'friendRequestUpdated',
      'action': 'rejected',
      'fromUserId': 'sender_200',
      'toUserId': 'receiver_100',
      'toNickName': '测试用户',
    });

    final notice = await service.handle(event, appIsForeground: true);

    expect(notice?.title, '好友申请已被拒绝');
    expect(notice?.body, '测试用户 拒绝了你的好友申请');
    expect(vibrationCount, 1);
    expect(soundCount, 1);
  });
}
