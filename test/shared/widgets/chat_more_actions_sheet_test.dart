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

      for (final label in [
        '照片/视频',
        '拍摄',
        '位置',
        '语音输入',
        '收藏',
        '个人名片',
        '文件',
        '音乐',
      ]) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('照片/视频'));
      await tester.pumpAndSettle();
      expect(selected, ChatMoreActionType.gallery);
    },
  );
}
