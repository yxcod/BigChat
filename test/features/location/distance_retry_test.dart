import 'dart:async';

import 'package:flutter_base/features/location/domain/distance_retry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stops after the configured number of failures', () async {
    var attempts = 0;

    await expectLater(
      runDistanceAttempts<int>(
        maxAttempts: 2,
        operation: () async {
          attempts++;
          throw Exception('unavailable');
        },
      ),
      throwsException,
    );

    expect(attempts, 2);
  });

  test('does not retry permanent failures', () async {
    var attempts = 0;

    await expectLater(
      runDistanceAttempts<int>(
        maxAttempts: 2,
        operation: () async {
          attempts++;
          throw Exception('permission denied');
        },
        shouldRetry: (_) => false,
      ),
      throwsException,
    );

    expect(attempts, 1);
  });

  test('times out each individual attempt', () async {
    var attempts = 0;

    await expectLater(
      runDistanceAttempts<int>(
        maxAttempts: 2,
        attemptTimeout: const Duration(milliseconds: 10),
        operation: () async {
          attempts++;
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return 1;
        },
      ),
      throwsA(isA<TimeoutException>()),
    );

    expect(attempts, 2);
  });
}
