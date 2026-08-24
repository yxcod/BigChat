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

  test('voice bubble grows with duration and progress stays normalized', () {
    expect(voiceBubbleWidth(1), lessThan(voiceBubbleWidth(15)));
    expect(voiceBubbleWidth(15), lessThan(voiceBubbleWidth(60)));
    expect(voiceBubbleWidth(120), voiceBubbleWidth(60));
    expect(
      voiceProgressFraction(
        const Duration(seconds: 5),
        const Duration(seconds: 20),
      ),
      0.25,
    );
    expect(
      voiceProgressFraction(
        const Duration(seconds: 30),
        const Duration(seconds: 20),
      ),
      1,
    );
  });

  test('voice transcription response parses cache and duration fields', () {
    final result = VoiceTranscriptionResult.fromJson({
      'text': '今天下午见。',
      'audioDurationMs': 2180,
      'cached': true,
    });

    expect(result.text, '今天下午见。');
    expect(result.audioDurationMs, 2180);
    expect(result.cached, isTrue);
  });
}
