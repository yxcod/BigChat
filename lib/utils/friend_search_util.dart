import 'package:flutter/material.dart';

class FriendSearchUtil {
  const FriendSearchUtil._();

  static bool matches({
    required String keyword,
    required String displayName,
    required String nickname,
  }) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) {
      return false;
    }
    return displayName.toLowerCase().contains(normalizedKeyword) ||
        nickname.toLowerCase().contains(normalizedKeyword);
  }

  static List<TextSpan> buildHighlightedSpans({
    required String text,
    required String keyword,
    required TextStyle normalStyle,
    required TextStyle highlightedStyle,
  }) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) {
      return [TextSpan(text: text, style: normalStyle)];
    }

    final normalizedText = text.toLowerCase();
    final spans = <TextSpan>[];
    var currentIndex = 0;
    while (currentIndex < text.length) {
      final matchIndex = normalizedText.indexOf(
        normalizedKeyword,
        currentIndex,
      );
      if (matchIndex < 0) {
        spans.add(
          TextSpan(text: text.substring(currentIndex), style: normalStyle),
        );
        break;
      }
      if (matchIndex > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, matchIndex),
            style: normalStyle,
          ),
        );
      }
      final matchEnd = matchIndex + normalizedKeyword.length;
      spans.add(
        TextSpan(
          text: text.substring(matchIndex, matchEnd),
          style: highlightedStyle,
        ),
      );
      currentIndex = matchEnd;
    }
    return spans;
  }
}
