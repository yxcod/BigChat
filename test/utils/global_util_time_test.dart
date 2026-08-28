import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/utils/gloabl.dart';

void main() {
  test('group conversation keys cannot collide with private user ids', () {
    expect(GlobalUtil.groupConversationKey(123), 'group:123');
    expect(GlobalUtil.groupConversationKey(123), isNot('123'));
  });

  test(
    'conversation visibility requires foreground and exact conversation',
    () {
      final global = GlobalUtil();
      global.resetSessionState();
      global.activateConversation('alice');

      expect(global.isConversationVisible('alice'), isTrue);
      expect(global.isConversationVisible('bob'), isFalse);

      global.setAppForeground(false);
      expect(global.isConversationVisible('alice'), isFalse);

      global.setAppForeground(true);
      global.deactivateConversation('bob');
      expect(global.isConversationVisible('alice'), isTrue);
      global.deactivateConversation('alice');
      expect(global.isConversationVisible('alice'), isFalse);
    },
  );

  group('GlobalUtil.formatChatTimestamp', () {
    final referenceTime = DateTime(2026, 8, 20, 15, 30);

    test('当天只显示时分', () {
      final timestamp = DateTime(2026, 8, 20, 9, 7).millisecondsSinceEpoch;

      expect(
        GlobalUtil.formatChatTimestamp(timestamp, referenceTime: referenceTime),
        '09:07',
      );
    });

    test('今年非当天显示月日时分', () {
      final timestamp = DateTime(2026, 3, 1, 9, 7).millisecondsSinceEpoch;

      expect(
        GlobalUtil.formatChatTimestamp(timestamp, referenceTime: referenceTime),
        '03-01 09:07',
      );
    });

    test('往年显示年月日时分', () {
      final timestamp = DateTime(2025, 12, 31, 23, 59).millisecondsSinceEpoch;

      expect(
        GlobalUtil.formatChatTimestamp(timestamp, referenceTime: referenceTime),
        '2025-12-31 23:59',
      );
    });

    test('兼容秒级时间戳', () {
      final timestamp =
          DateTime(2026, 8, 20, 9, 7).millisecondsSinceEpoch ~/ 1000;

      expect(
        GlobalUtil.formatChatTimestamp(timestamp, referenceTime: referenceTime),
        '09:07',
      );
    });
  });
}
