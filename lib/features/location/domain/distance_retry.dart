import 'dart:async';

Future<T> runDistanceAttempts<T>({
  required Future<T> Function() operation,
  int maxAttempts = 2,
  Duration attemptTimeout = const Duration(seconds: 5),
  bool Function(Object error)? shouldRetry,
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
  }

  Object? lastError;
  StackTrace? lastStackTrace;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await operation().timeout(attemptTimeout);
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      if (shouldRetry != null && !shouldRetry(error)) break;
    }
  }
  Error.throwWithStackTrace(lastError!, lastStackTrace!);
}
