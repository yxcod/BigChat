import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_base/shared/widgets/chat_time_separator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('首条消息、跨日或间隔五分钟时显示时间标签', () {
    final first = _message(DateTime(2026, 8, 25, 10));
    final nearby = _message(DateTime(2026, 8, 25, 10, 3));
    final later = _message(DateTime(2026, 8, 25, 10, 8));
    final nextDay = _message(DateTime(2026, 8, 26, 9));

    expect(shouldShowChatTimeSeparator(current: first, previous: null), isTrue);
    expect(
      shouldShowChatTimeSeparator(current: nearby, previous: first),
      isFalse,
    );
    expect(
      shouldShowChatTimeSeparator(current: later, previous: nearby),
      isTrue,
    );
    expect(
      shouldShowChatTimeSeparator(current: nextDay, previous: later),
      isTrue,
    );
  });

  testWidgets('好友验证消息分界提示保持居中展示', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: FriendVerificationDivider()),
      ),
    );

    expect(find.text('以上为验证消息'), findsOneWidget);
    expect(find.byType(Center), findsWidgets);
  });
}

Message _message(DateTime time) {
  return Message(
    msgId: time.millisecondsSinceEpoch,
    content: '消息',
    isMe: false,
    time: '10:00',
    isRead: true,
    conversationId: 'chat',
    timestamp: time.millisecondsSinceEpoch,
  );
}
