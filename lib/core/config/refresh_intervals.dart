class RefreshIntervals {
  const RefreshIntervals._();

  /// WebSocket events and explicit user actions refresh immediately.
  /// Polling only recovers missed events and should stay low frequency.
  static const conversationFallback = Duration(minutes: 5);
  static const friendFallback = Duration(minutes: 5);
  static const groupFallback = Duration(minutes: 5);
}
