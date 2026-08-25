import 'package:flutter_base/features/privacy/domain/privacy_settings.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('privacy destroy delays stay inside supported ranges', () {
    const settings = PrivacySettings();

    expect(settings.copyWith(readDestroySeconds: 1).readDestroySeconds, 5);
    expect(settings.copyWith(readDestroySeconds: 100).readDestroySeconds, 60);
    expect(settings.copyWith(unreadDestroySeconds: 1).unreadDestroySeconds, 60);
    expect(
      settings.copyWith(unreadDestroySeconds: 999).unreadDestroySeconds,
      300,
    );
  });

  test('privacy message metadata survives in-memory JSON mapping', () {
    final message = Message(
      msgId: 42,
      content: 'secret',
      isMe: true,
      time: '12:00',
      isRead: false,
      conversationId: 'alice_bob',
      isPrivacy: true,
      privacyReadDelaySeconds: 25,
      privacyUnreadDelaySeconds: 240,
    );

    final restored = Message.fromJSON(message.toJSON());
    expect(restored.isPrivacy, isTrue);
    expect(restored.privacyReadDelaySeconds, 25);
    expect(restored.privacyUnreadDelaySeconds, 240);
  });
}
