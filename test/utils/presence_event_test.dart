import 'package:flutter_base/utils/presence_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses online and offline presence events', () {
    final online = PresenceEvent.tryParse({
      'type': 'presence',
      'userName': 'friend',
      'onlineStatus': true,
    });
    final offline = PresenceEvent.tryParse({
      'type': 'presence',
      'userName': 'friend',
      'onlineStatus': '0',
    });

    expect(online?.userName, 'friend');
    expect(online?.isOnline, isTrue);
    expect(offline?.isOnline, isFalse);
  });

  test('ignores unrelated or incomplete websocket messages', () {
    expect(PresenceEvent.tryParse({'type': 'chat'}), isNull);
    expect(
      PresenceEvent.tryParse({'type': 'presence', 'onlineStatus': true}),
      isNull,
    );
  });
}
