class PrivacySettings {
  const PrivacySettings({
    this.enabled = false,
    this.readDestroySeconds = 10,
    this.unreadDestroySeconds = 180,
    this.gestureSalt = '',
    this.gestureDigest = '',
  });

  final bool enabled;
  final int readDestroySeconds;
  final int unreadDestroySeconds;
  final String gestureSalt;
  final String gestureDigest;

  bool get hasGesturePassword =>
      gestureSalt.isNotEmpty && gestureDigest.isNotEmpty;

  PrivacySettings copyWith({
    bool? enabled,
    int? readDestroySeconds,
    int? unreadDestroySeconds,
    String? gestureSalt,
    String? gestureDigest,
  }) {
    return PrivacySettings(
      enabled: enabled ?? this.enabled,
      readDestroySeconds: (readDestroySeconds ?? this.readDestroySeconds)
          .clamp(5, 60)
          .toInt(),
      unreadDestroySeconds: (unreadDestroySeconds ?? this.unreadDestroySeconds)
          .clamp(60, 300)
          .toInt(),
      gestureSalt: gestureSalt ?? this.gestureSalt,
      gestureDigest: gestureDigest ?? this.gestureDigest,
    );
  }
}
