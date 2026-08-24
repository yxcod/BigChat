import 'package:flutter_base/core/media/voice_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice payload preserves filename and duration', () {
    const payload = VoiceMessagePayload(
      audioName: 'alice_bob_1.m4a',
      durationMs: 2450,
      ownerId: 'alice',
    );

    final decoded = VoiceMessagePayload.parse(payload.encode());

    expect(decoded.audioName, 'alice_bob_1.m4a');
    expect(decoded.durationMs, 2450);
    expect(decoded.ownerId, 'alice');
    expect(decoded.durationSeconds, 3);
  });

  test('legacy plain filename remains playable', () {
    final decoded = VoiceMessagePayload.parse('old_voice.m4a');

    expect(decoded.audioName, 'old_voice.m4a');
    expect(decoded.ownerId, isNull);
    expect(decoded.durationSeconds, 1);
  });

  test('conversation preview hides the audio payload JSON', () {
    expect(
      chatVoicePreview('{"audioName":"alice_bob_1.m4a","durationMs":2450}'),
      '[语音]',
    );
    expect(chatVoicePreview('普通文本'), '普通文本');
  });
}
