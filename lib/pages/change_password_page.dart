import 'package:flutter/material.dart';
import '../core/notifications/push_notification_service.dart';

import '../api/getInfoAPI.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_theme_context.dart';
import '../utils/WebSocketManager.dart';
import '../utils/gloabl.dart';
import '../utils/storageUtil.dart';

/// Allows the password request to be replaced in widget tests.
typedef PasswordChanger =
    Future<int> Function(
      String userName,
      String oldPassword,
      String newPassword,
    );

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    super.key,
    this.passwordChanger,
    this.logoutHandler,
  });

  final PasswordChanger? passwordChanger;
  final Future<void> Function()? logoutHandler;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordFocusNode = FocusNode();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordFocusNode.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty) {
      _showMessage('请输入当前密码');
      return;
    }
    if (newPassword.isEmpty) {
      _showMessage('请输入新密码');
      return;
    }
    if (newPassword.length < 6) {
      _showMessage('新密码长度不能少于6位');
      return;
    }
    if (newPassword != confirmPassword) {
      _showMessage('两次输入的密码不一致');
      return;
    }

    final userName = GlobalUtil().userName ?? '';
    if (userName.isEmpty) {
      _showMessage('无法获取当前用户信息');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final changer = widget.passwordChanger ?? changePasswordApi;
      final code = await changer(userName, currentPassword, newPassword);
      if (!mounted) return;

      if (code != 100) {
        _showMessage('密码修改失败，请检查当前密码是否正确');
        return;
      }

      _showMessage('密码修改成功，即将退出登录');
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await _logout();
    } catch (error) {
      debugPrint('修改密码失败：$error');
      if (mounted) _showMessage('密码修改失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _logout() async {
    if (widget.logoutHandler != null) {
      await widget.logoutHandler!();
      return;
    }

    WebSocketManager().disconnect();
    await PushNotificationService.instance.unregisterCurrentUser();
    final globalUtil = GlobalUtil();
    await globalUtil.flushChatRecordsToLocal();
    globalUtil.resetSessionState();
    await StorageUtil.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Widget _passwordField({
    required Key key,
    required TextEditingController controller,
    required String hintText,
    FocusNode? focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      autofocus: focusNode != null,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: textInputAction,
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: context.appTextSecondary),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
      ),
      style: const TextStyle(fontSize: 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.appSurface,
        surfaceTintColor: context.appSurface,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 76,
        leading: TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(
            '取消',
            style: TextStyle(color: context.appTextPrimary, fontSize: 16),
          ),
        ),
        title: const Text('修改密码'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('change_password_complete_button'),
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(58, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('完成'),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ColoredBox(
            color: context.appSurface,
            child: Column(
              children: [
                _passwordField(
                  key: const Key('current_password_field'),
                  controller: _currentPasswordController,
                  focusNode: _currentPasswordFocusNode,
                  hintText: '请输入当前密码',
                ),
                const Divider(height: 0.5, indent: 16),
                _passwordField(
                  key: const Key('new_password_field'),
                  controller: _newPasswordController,
                  hintText: '请输入新密码（不少于6位）',
                ),
                const Divider(height: 0.5, indent: 16),
                _passwordField(
                  key: const Key('confirm_password_field'),
                  controller: _confirmPasswordController,
                  hintText: '请再次输入新密码',
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              '密码修改成功后，需要使用新密码重新登录。',
              style: TextStyle(color: context.appTextSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
