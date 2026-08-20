import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/utils/chat_search_util.dart';

void main() {
  group('ChatSearchUtil', () {
    test('忽略英文大小写匹配聊天内容', () {
      expect(ChatSearchUtil.matches('Hello Flutter', 'hello'), isTrue);
      expect(ChatSearchUtil.matches('Hello Flutter', 'Dart'), isFalse);
    });

    test('长消息摘要保留关键词并添加省略号', () {
      final preview = ChatSearchUtil.buildPreview(
        '这是一段很长的聊天内容，需要确保中间的关键词能够展示出来，后面还有很多文字',
        '关键词',
        contextLength: 4,
      );

      expect(preview, contains('关键词'));
      expect(preview, startsWith('…'));
      expect(preview, endsWith('…'));
    });

    test('所有匹配文字均生成高亮片段', () {
      const highlightedStyle = TextStyle(color: Colors.green);
      final spans = ChatSearchUtil.buildHighlightedSpans(
        content: '你好，你好呀',
        keyword: '你好',
        normalStyle: const TextStyle(color: Colors.grey),
        highlightedStyle: highlightedStyle,
      );
      final highlighted = spans
          .where((span) => span.style == highlightedStyle)
          .map((span) => span.text)
          .toList();

      expect(highlighted, ['你好', '你好']);
    });
  });
}
