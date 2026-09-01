import 'package:flutter_base/features/calls/domain/call_signal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppCallSignal', () {
    test('round-trips a private call signal', () {
      const signal = AppCallSignal(
        callId: 'private_alice_1',
        kind: AppCallKind.private,
        action: AppCallAction.invite,
        channelName: 'quanxin_private_alice_1',
        senderId: 'alice',
        senderName: 'Alice',
        receiverId: 'bob',
        token: 'rtc-token',
        sentAt: 123,
      );

      final parsed = AppCallSignal.tryParse(signal.toWire());

      expect(parsed, isNotNull);
      expect(parsed!.callId, signal.callId);
      expect(parsed.kind, AppCallKind.private);
      expect(parsed.action, AppCallAction.invite);
      expect(parsed.receiverId, 'bob');
      expect(parsed.token, 'rtc-token');
      expect(parsed.sentAt, 123);
    });

    test('parses group accept and numeric string group id', () {
      final parsed = AppCallSignal.tryParse({
        'type': 'callSignal',
        'callId': 'group_8_1',
        'callKind': 'group',
        'action': 'accept',
        'channelName': 'quanxin_group_8_1',
        'sender': 'bob',
        'senderName': 'Bob',
        'receiver': 'alice',
        'groupId': '8',
      });

      expect(parsed, isNotNull);
      expect(parsed!.isGroup, isTrue);
      expect(parsed.groupId, 8);
      expect(parsed.action, AppCallAction.accept);
      expect(parsed.receiverId, 'alice');
    });

    test('keeps legacy invite and accept in the same channel call id', () {
      final invite = AppCallSignal.tryParse({
        'type': 'videoCallInvite',
        'channelName': 'legacy_channel',
        'sender': 'alice',
      });
      final accept = AppCallSignal.tryParse({
        'type': 'videoCallAccept',
        'channelName': 'legacy_channel',
        'sender': 'bob',
      });

      expect(invite, isNotNull);
      expect(accept, isNotNull);
      expect(invite!.callId, accept!.callId);
      expect(invite.action, AppCallAction.invite);
      expect(accept.action, AppCallAction.accept);
    });

    test('rejects malformed or unsupported payloads', () {
      expect(AppCallSignal.tryParse('not-a-map'), isNull);
      expect(
        AppCallSignal.tryParse({
          'type': 'callSignal',
          'action': 'unknown',
          'channelName': 'channel',
          'sender': 'alice',
        }),
        isNull,
      );
      expect(
        AppCallSignal.tryParse({
          'type': 'callSignal',
          'action': 'invite',
          'sender': 'alice',
        }),
        isNull,
      );
    });
  });

  test('call session measures duration after connection', () {
    const signal = AppCallSignal(
      callId: 'private_alice_1',
      kind: AppCallKind.private,
      action: AppCallAction.invite,
      channelName: 'quanxin_private_alice_1',
      senderId: 'alice',
      senderName: 'Alice',
    );
    const session = AppCallSession(
      signal: signal,
      phase: AppCallPhase.connected,
      isCaller: true,
      connectedAt: 1000,
    );

    expect(session.durationSecondsAt(25 * 1000), 24);
  });
}
