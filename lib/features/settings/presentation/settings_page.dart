import 'package:flutter/material.dart';
import '../../../core/notifications/push_notification_service.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../app/theme/app_theme_controller.dart';
import '../../../utils/WebSocketManager.dart';
import '../../../utils/gloabl.dart';
import '../../../utils/storageUtil.dart';
import '../../location/data/app_location_service.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';
import 'notification_settings_page.dart';
import 'theme_settings_page.dart';
import '../../privacy/application/privacy_settings_service.dart';
import '../../privacy/presentation/privacy_settings_page.dart';

typedef ChatBackgroundPicker = Future<String?> Function();
typedef LocationPreferenceHandler = Future<void> Function(bool enabled);

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.repository,
    this.pickChatBackground,
    this.themeController,
    this.logoutHandler,
    this.locationPreferenceHandler,
  });

  final AppSettingsRepository? repository;
  final ChatBackgroundPicker? pickChatBackground;
  final AppThemeController? themeController;
  final Future<void> Function()? logoutHandler;
  final LocationPreferenceHandler? locationPreferenceHandler;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AppSettingsRepository _repository;
  late final AppThemeController _themeController;
  AppSettings _settings = const AppSettings();
  bool _loading = true;
  bool _savingBackground = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        AppSettingsRepository(ownerId: GlobalUtil().userName ?? '');
    _themeController = widget.themeController ?? AppThemeController.instance;
    _themeController.addListener(_handleThemeChanged);
    _load();
  }

  @override
  void dispose() {
    _themeController.removeListener(_handleThemeChanged);
    super.dispose();
  }

  void _handleThemeChanged() {
    if (mounted) setState(() {});
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
    if (widget.repository == null &&
        value &&
        !PrivacySettingsService.instance.settings.hasGesturePassword) {
      final configured = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SetGesturePasswordPage()),
      );
      if (configured != true) return;
    }
    setState(() => _settings = _settings.copyWith(privacyMode: value));
    await _repository.setPrivacyMode(value);
    if (widget.repository == null) {
      await PrivacySettingsService.instance.setEnabled(value);
    }
  }

  Future<void> _setLocationEnabled(bool value) async {
    setState(() => _settings = _settings.copyWith(locationEnabled: value));
    await _repository.setLocationEnabled(value);
    try {
      if (widget.locationPreferenceHandler != null) {
        await widget.locationPreferenceHandler!(value);
      } else {
        await AppLocationService().reconcileServerPreference();
      }
    } catch (_) {
      // The app-level five-minute reconciliation and foreground resume hook
      // retry this operation when the network becomes available again.
    }
  }

  Future<void> _selectChatBackground() async {
    if (_savingBackground) return;
    setState(() => _savingBackground = true);
    try {
      final sourcePath = widget.pickChatBackground != null
          ? await widget.pickChatBackground!()
          : (await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 90,
              maxWidth: 2048,
              maxHeight: 2048,
            ))?.path;
      if (sourcePath == null || sourcePath.isEmpty) return;

      final savedPath = await _repository.importChatBackground(sourcePath);
      if (!mounted) return;
      setState(
        () => _settings = _settings.copyWith(chatBackgroundPath: savedPath),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('聊天背景已更新'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('选择聊天背景失败：$error'),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingBackground = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后将返回登录页面，本地账号登录状态会被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const Key('confirm_logout_button'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              '退出登录',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (widget.logoutHandler != null) {
      await widget.logoutHandler!();
    } else {
      await PushNotificationService.instance.unregisterCurrentUser();
      WebSocketManager().disconnect();
      final global = GlobalUtil();
      await global.flushChatRecordsToLocal();
      global.resetSessionState();
      await StorageUtil.logout();
    }
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 12),
                Material(
                  color: context.appSurface,
                  child: Column(
                    children: [
                      _SettingsSwitchTile(
                        key: const Key('privacy_mode_switch'),
                        title: '隐私模式',
                        value: _settings.privacyMode,
                        onChanged: _setPrivacyMode,
                      ),
                      Divider(height: 1, indent: 16, color: context.appDivider),
                      ListTile(
                        key: const Key('privacy_settings_entry'),
                        title: const Text('隐私参数设置'),
                        subtitle: const Text('消息销毁时间与手势密码'),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: context.appTextSecondary,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacySettingsPage(),
                          ),
                        ),
                      ),
                      Divider(height: 1, indent: 16, color: context.appDivider),
                      _SettingsSwitchTile(
                        key: const Key('location_enabled_switch'),
                        title: '位置信息',
                        value: _settings.locationEnabled,
                        onChanged: _setLocationEnabled,
                      ),
                      Divider(height: 1, indent: 16, color: context.appDivider),
                      ListTile(
                        key: const Key('theme_settings_entry'),
                        title: const Text('主题设置'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _themeController.isDark ? '深色' : '浅色',
                              style: TextStyle(color: context.appTextSecondary),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: context.appTextSecondary,
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ThemeSettingsPage(controller: _themeController),
                          ),
                        ),
                      ),
                      Divider(height: 1, indent: 16, color: context.appDivider),
                      ListTile(
                        key: const Key('chat_background_settings_entry'),
                        title: const Text('聊天背景设置'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_savingBackground)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Text(
                                _settings.chatBackgroundPath.isEmpty
                                    ? '默认'
                                    : '已设置',
                                style: TextStyle(
                                  color: context.appTextSecondary,
                                ),
                              ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: context.appTextSecondary,
                            ),
                          ],
                        ),
                        onTap: _savingBackground ? null : _selectChatBackground,
                      ),
                      Divider(height: 1, indent: 16, color: context.appDivider),
                      ListTile(
                        key: const Key('notification_settings_entry'),
                        title: const Text('通知'),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: context.appTextSecondary,
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
                const SizedBox(height: 20),
                Material(
                  color: context.appSurface,
                  child: ListTile(
                    key: const Key('logout_button'),
                    title: const Center(
                      child: Text(
                        '退出登录',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onTap: _confirmLogout,
                  ),
                ),
                const SizedBox(height: 28),
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
