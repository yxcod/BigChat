import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/utils/friend_search_util.dart';

void main() {
  group('FriendSearchUtil', () {
    test('可以通过备注匹配好友', () {
      expect(
        FriendSearchUtil.matches(
          keyword: '同事',
          displayName: '同事小张',
          nickname: '张三',
        ),
        isTrue,
      );
    });

    test('可以通过昵称匹配好友且忽略英文大小写', () {
      expect(
        FriendSearchUtil.matches(
          keyword: 'alice',
          displayName: '产品经理',
          nickname: 'Alice Zhang',
        ),
        isTrue,
      );
    });

    test('所有命中文字都会生成高亮片段', () {
      const highlightedStyle = TextStyle(color: Colors.green);
      final spans = FriendSearchUtil.buildHighlightedSpans(
        text: '小张和张老师',
        keyword: '张',
        normalStyle: const TextStyle(color: Colors.black),
        highlightedStyle: highlightedStyle,
      );
      final highlighted = spans
          .where((span) => span.style == highlightedStyle)
          .map((span) => span.text)
          .toList();

      expect(highlighted, ['张', '张']);
    });
  });
}
