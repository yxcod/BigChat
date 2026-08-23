import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../utils/gloabl.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';
import 'notification_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.repository});

  final AppSettingsRepository? repository;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AppSettingsRepository _repository;
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        AppSettingsRepository(ownerId: GlobalUtil().userName ?? '');
    _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _setPrivacyMode(bool value) async {
    setState(() => _settings = _settings.copyWith(privacyMode: value));
    await _repository.setPrivacyMode(value);
  }

  Future<void> _setLocationEnabled(bool value) async {
    setState(() => _settings = _settings.copyWith(locationEnabled: value));
    await _repository.setLocationEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),
                Material(
                  color: Colors.white,
                  child: Column(
                    children: [
                      _SettingsSwitchTile(
                        key: const Key('privacy_mode_switch'),
                        title: '隐私模式',
                        value: _settings.privacyMode,
                        onChanged: _setPrivacyMode,
                      ),
                      const Divider(
                        height: 1,
                        indent: 16,
                        color: Color(0xFFE5E5E5),
                      ),
                      _SettingsSwitchTile(
                        key: const Key('location_enabled_switch'),
                        title: '位置信息',
                        value: _settings.locationEnabled,
                        onChanged: _setLocationEnabled,
                      ),
                      const Divider(
                        height: 1,
                        indent: 16,
                        color: Color(0xFFE5E5E5),
                      ),
                      ListTile(
                        key: const Key('notification_settings_entry'),
                        title: const Text('通知'),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFB6B6B6),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NotificationSettingsPage(
                                repository: _repository,
                              ),
                            ),
                          );
                          await _load();
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

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
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
