import 'package:flutter_base/features/chat/domain/private_delivery_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes a removed-friend delivery rejection', () {
    expect(
      PrivateDeliveryFailure.isNotFriends({
        'type': 'delivery_ack',
        'status': 'failed',
        'code': 403,
        'errorCode': 'not_friends',
      }),
      isTrue,
    );
    expect(
      PrivateDeliveryFailure.isNotFriends({
        'type': 'delivery_ack',
        'status': 'failed',
        'reason': 'network_error',
      }),
      isFalse,
    );
  });
}
