import 'package:flutter/material.dart';
import 'package:flutter_base/core/media/voice_message.dart';
import 'package:flutter_base/shared/widgets/hold_to_record_field.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVoiceRecorder implements VoiceRecorderController {
  bool started = false;
  bool stopped = false;

  @override
  Future<void> start() async => started = true;

  @override
  Future<VoiceRecordingResult?> stop() async {
    stopped = true;
    return const VoiceRecordingResult(path: '/tmp/voice.m4a', durationMs: 1000);
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('chat input shows the voice recording hint by default', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoldToRecordField(
            controller: controller,
            focusNode: focusNode,
            onChanged: (_) {},
            onSubmitted: (_) {},
            onRecorded: (_) async {},
            onError: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('长按发送语音'), findsOneWidget);
  });

  testWidgets('holding anywhere on the editor starts and sends recording', (
    tester,
  ) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    final recorder = _FakeVoiceRecorder();
    VoiceRecordingResult? recorded;
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoldToRecordField(
            controller: controller,
            focusNode: focusNode,
            recorder: recorder,
            holdDuration: const Duration(milliseconds: 100),
            onChanged: (_) {},
            onSubmitted: (_) {},
            onRecorded: (result) async => recorded = result,
            onError: (_) {},
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldToRecordField)),
    );
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump();
    expect(recorder.started, isTrue);
    expect(find.textContaining('松开发送'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(recorder.stopped, isTrue);
    expect(recorded?.durationMs, 1000);
  });
}
