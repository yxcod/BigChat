import 'package:flutter_base/features/account/application/session_termination_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a replaced-session event', () {
    final event = SessionTerminationEvent.parse({
      'type': 'sessionReplaced',
      'message': '你的账号已在其他设备登录',
    });
    expect(event, isNotNull);
    expect(event!.title, '账号已在其他设备登录');
    expect(event.message, '你的账号已在其他设备登录');
  });

  test('ignores ordinary realtime events', () {
    expect(SessionTerminationEvent.parse({'type': 'message'}), isNull);
  });
}
