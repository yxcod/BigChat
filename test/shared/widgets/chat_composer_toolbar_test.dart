import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/chat_composer_toolbar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('聊天输入栏移除左侧麦克风并扩大编辑区域', (tester) async {
    tester.view.physicalSize = const Size(390, 120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
            onMedia: () => mediaTapped = true,
            onMore: () => moreTapped = true,
            onSend: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('chat_voice_hint_button')), findsNothing);
    expect(find.byKey(const Key('chat_media_button')), findsOneWidget);
    expect(find.byKey(const Key('chat_more_button')), findsOneWidget);
    expect(find.byKey(const Key('chat_send_button')), findsNothing);
    expect(
      tester.getSize(find.byKey(const Key('editor'))).width,
      greaterThan(280),
    );
    await tester.tap(find.byKey(const Key('chat_media_button')));
    await tester.tap(find.byKey(const Key('chat_more_button')));
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
