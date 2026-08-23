class AppSettings {
  const AppSettings({
    this.privacyMode = false,
    this.locationEnabled = true,
    this.vibrationEnabled = true,
    this.bannerEnabled = true,
    this.messageSoundEnabled = true,
    this.messageSoundId = NotificationSound.systemDefaultId,
  });

  final bool privacyMode;
  final bool locationEnabled;
  final bool vibrationEnabled;
  final bool bannerEnabled;
  final bool messageSoundEnabled;
  final String messageSoundId;

  AppSettings copyWith({
    bool? privacyMode,
    bool? locationEnabled,
    bool? vibrationEnabled,
    bool? bannerEnabled,
    bool? messageSoundEnabled,
    String? messageSoundId,
  }) {
    return AppSettings(
      privacyMode: privacyMode ?? this.privacyMode,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      bannerEnabled: bannerEnabled ?? this.bannerEnabled,
      messageSoundEnabled: messageSoundEnabled ?? this.messageSoundEnabled,
      messageSoundId: messageSoundId ?? this.messageSoundId,
    );
  }
}

class NotificationSound {
  const NotificationSound({required this.id, required this.label});

  static const systemDefaultId = 'system_default';

  final String id;
  final String label;

  static const values = <NotificationSound>[
    NotificationSound(id: systemDefaultId, label: '系统默认'),
    NotificationSound(id: 'tri_tone', label: '三全音'),
    NotificationSound(id: 'note', label: '圆点'),
    NotificationSound(id: 'glass', label: '玻璃'),
    NotificationSound(id: 'bell', label: '铃声'),
  ];

  static NotificationSound byId(String id) {
    return values.firstWhere(
      (sound) => sound.id == id,
      orElse: () => values.first,
    );
  }
}
