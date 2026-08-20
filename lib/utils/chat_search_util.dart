import 'package:flutter/material.dart';

class ChatSearchUtil {
  const ChatSearchUtil._();

  static bool matches(String content, String keyword) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) {
      return false;
    }
    return content.toLowerCase().contains(normalizedKeyword);
  }

  static String buildPreview(
    String content,
    String keyword, {
    int contextLength = 20,
  }) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    final normalizedContent = content.toLowerCase();
    final matchIndex = normalizedContent.indexOf(normalizedKeyword);
    if (matchIndex < 0) {
      return content;
    }

    final start = (matchIndex - contextLength).clamp(0, content.length);
    final end = (matchIndex + keyword.trim().length + contextLength).clamp(
      0,
      content.length,
    );
    return '${start > 0 ? '…' : ''}'
        '${content.substring(start, end)}'
        '${end < content.length ? '…' : ''}';
  }

  static List<TextSpan> buildHighlightedSpans({
    required String content,
    required String keyword,
    required TextStyle normalStyle,
    required TextStyle highlightedStyle,
  }) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) {
      return [TextSpan(text: content, style: normalStyle)];
    }

    final normalizedContent = content.toLowerCase();
    final spans = <TextSpan>[];
    var currentIndex = 0;

    while (currentIndex < content.length) {
      final matchIndex = normalizedContent.indexOf(
        normalizedKeyword,
        currentIndex,
      );
      if (matchIndex < 0) {
        spans.add(
          TextSpan(text: content.substring(currentIndex), style: normalStyle),
        );
        break;
      }
      if (matchIndex > currentIndex) {
        spans.add(
          TextSpan(
            text: content.substring(currentIndex, matchIndex),
            style: normalStyle,
          ),
        );
      }
      final matchEnd = matchIndex + normalizedKeyword.length;
      spans.add(
        TextSpan(
          text: content.substring(matchIndex, matchEnd),
          style: highlightedStyle,
        ),
      );
      currentIndex = matchEnd;
    }

    return spans;
  }
}
