import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/chat_more_actions_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'more actions sheet shows the reference actions and returns tap',
    (tester) async {
      ChatMoreActionType? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<ChatMoreActionType>(
                    context: context,
                    builder: (_) => const ChatMoreActionsSheet(),
                  );
                },
                child: const Text('更多'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('更多'));
      await tester.pumpAndSettle();

      for (final label in ['照片/视频', '拍摄', '位置', '文件']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final removedLabel in ['语音输入', '收藏', '个人名片', '音乐']) {
        expect(find.text(removedLabel), findsNothing);
      }

      await tester.tap(find.text('照片/视频'));
      await tester.pumpAndSettle();
      expect(selected, ChatMoreActionType.gallery);
    },
  );

  testWidgets('inline actions stay below the input and report selection', (
    tester,
  ) async {
    ChatMoreActionType? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Spacer(),
              const Text('输入栏'),
              ChatMoreActionsSheet(onSelected: (action) => selected = action),
            ],
          ),
        ),
      ),
    );

    final inputTop = tester.getTopLeft(find.text('输入栏')).dy;
    final menuTop = tester.getTopLeft(find.text('照片/视频')).dy;
    expect(inputTop, lessThan(menuTop));

    await tester.tap(find.text('拍摄'));
    await tester.pump();

    expect(selected, ChatMoreActionType.capture);
    expect(find.text('输入栏'), findsOneWidget);
    expect(find.text('照片/视频'), findsOneWidget);
  });
}
