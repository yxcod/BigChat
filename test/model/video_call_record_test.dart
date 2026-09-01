import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const record = VideoCallRecord(
    callId: 'private_alice_1',
    outcome: VideoCallOutcome.completed,
    callerId: 'alice',
    peerId: 'bob',
    durationSeconds: 1464,
  );

  test('round-trips through message extend info', () {
    final encoded = const MessageExtensions(videoCallRecord: record).encode();
    final decoded = MessageExtensions.fromExtendInfo(encoded).videoCallRecord;

    expect(decoded, isNotNull);
    expect(decoded!.callId, 'private_alice_1');
    expect(decoded.outcome, VideoCallOutcome.completed);
    expect(decoded.formattedDuration, '24:24');
  });

  test('uses perspective-aware missed call labels', () {
    const rejected = VideoCallRecord(
      callId: 'private_alice_2',
      outcome: VideoCallOutcome.rejected,
      callerId: 'alice',
      peerId: 'bob',
    );
    const noAnswer = VideoCallRecord(
      callId: 'private_alice_3',
      outcome: VideoCallOutcome.noAnswer,
      callerId: 'alice',
      peerId: 'bob',
    );

    expect(rejected.displayText(isMe: true), '对方已拒绝');
    expect(rejected.displayText(isMe: false), '已拒绝');
    expect(noAnswer.displayText(isMe: true), '对方无人接听');
    expect(noAnswer.displayText(isMe: false), '未接听');
  });

  test('survives local message cache serialization', () {
    final message = Message(
      msgId: 1,
      content: '通话时长 24:24',
      isMe: true,
      time: '21:32',
      isRead: false,
      conversationId: 'bob_alice',
      videoCallRecord: record,
    );

    final restored = Message.fromJSON(message.toJSON());
    expect(restored.videoCallRecord?.outcome, VideoCallOutcome.completed);
    expect(messageQuotePreview(restored), '[视频通话] 通话时长 24:24');
  });
}
