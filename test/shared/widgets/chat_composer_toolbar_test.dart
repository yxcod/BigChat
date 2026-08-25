import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/chat_composer_toolbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('聊天输入栏空闲时显示语音、媒体和更多入口', (tester) async {
    tester.view.physicalSize = const Size(390, 120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var voiceTapped = false;
    var mediaTapped = false;
    var moreTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposerToolbar(
            editor: const SizedBox(
              key: Key('editor'),
              height: 46,
              child: ColoredBox(color: Color(0xFFF3F3F5)),
            ),
            isComposing: false,
            isUploadingAudio: false,
            isUploadingMedia: false,
            onVoiceHint: () => voiceTapped = true,
            onMedia: () => mediaTapped = true,
            onMore: () => moreTapped = true,
            onSend: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('chat_voice_hint_button')), findsOneWidget);
    expect(find.byKey(const Key('chat_media_button')), findsOneWidget);
    expect(find.byKey(const Key('chat_more_button')), findsOneWidget);
    expect(find.byKey(const Key('chat_send_button')), findsNothing);
    await tester.tap(find.byKey(const Key('chat_voice_hint_button')));
    await tester.tap(find.byKey(const Key('chat_media_button')));
    await tester.tap(find.byKey(const Key('chat_more_button')));
    expect(voiceTapped, isTrue);
    expect(mediaTapped, isTrue);
    expect(moreTapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('输入文字后发送按钮替换更多按钮', (tester) async {
    var sent = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposerToolbar(
            editor: const SizedBox(height: 46),
            isComposing: true,
            isUploadingAudio: false,
            isUploadingMedia: false,
            onVoiceHint: () {},
            onMedia: () {},
            onMore: () {},
            onSend: () => sent = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('chat_send_button')), findsOneWidget);
    expect(find.byKey(const Key('chat_more_button')), findsNothing);
    await tester.tap(find.byKey(const Key('chat_send_button')));
    expect(sent, isTrue);
  });
}
