import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';
import 'sound_selection_page.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, required this.repository});

  final AppSettingsRepository repository;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.repository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _update(
    AppSettings settings,
    Future<void> Function() persist,
  ) async {
    setState(() => _settings = settings);
    await persist();
  }

  @override
  Widget build(BuildContext context) {
    final selectedSound = NotificationSound.byId(_settings.messageSoundId);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('通知')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),
                Material(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _NotificationSwitchTile(
                        key: const Key('vibration_switch'),
                        title: '震动',
                        value: _settings.vibrationEnabled,
                        onChanged: (value) => _update(
                          _settings.copyWith(vibrationEnabled: value),
                          () => widget.repository.setVibrationEnabled(value),
                        ),
                      ),
                      const _SettingsDivider(),
                      _NotificationSwitchTile(
                        key: const Key('banner_switch'),
                        title: '横幅',
                        value: _settings.bannerEnabled,
                        onChanged: (value) => _update(
                          _settings.copyWith(bannerEnabled: value),
                          () => widget.repository.setBannerEnabled(value),
                        ),
                      ),
                      const _SettingsDivider(),
                      _NotificationSwitchTile(
                        key: const Key('message_sound_switch'),
                        title: '消息提示音',
                        value: _settings.messageSoundEnabled,
                        onChanged: (value) => _update(
                          _settings.copyWith(messageSoundEnabled: value),
                          () => widget.repository.setMessageSoundEnabled(value),
                        ),
                      ),
                      const _SettingsDivider(),
                      ListTile(
                        key: const Key('message_sound_settings_entry'),
                        title: const Text('消息提示音设置'),
                        enabled: _settings.messageSoundEnabled,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedSound.label,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFB6B6B6),
                            ),
                          ],
                        ),
                        onTap: () async {
                          final soundId = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SoundSelectionPage(
                                selectedSoundId: _settings.messageSoundId,
                              ),
                            ),
                          );
                          if (soundId == null || !mounted) return;
                          await _update(
                            _settings.copyWith(messageSoundId: soundId),
                            () => widget.repository.setMessageSoundId(soundId),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _NotificationSwitchTile extends StatelessWidget {
  const _NotificationSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
      onChanged: onChanged,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 16, color: Color(0xFFE5E5E5));
  }
}
