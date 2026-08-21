import 'package:flutter_base/core/config/refresh_intervals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fallback refreshes do not poll large resources aggressively', () {
    expect(
      RefreshIntervals.conversationFallback,
      greaterThanOrEqualTo(const Duration(minutes: 5)),
    );
    expect(
      RefreshIntervals.friendFallback,
      greaterThanOrEqualTo(const Duration(minutes: 5)),
    );
    expect(
      RefreshIntervals.groupFallback,
      greaterThanOrEqualTo(const Duration(minutes: 5)),
    );
  });
}
