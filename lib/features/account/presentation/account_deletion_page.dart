import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../utils/WebSocketManager.dart';
import '../../../utils/gloabl.dart';
import '../../../utils/storageUtil.dart';
import '../data/account_deletion_repository.dart';

typedef AccountDeletionExecutor =
    Future<AccountDeletionResult> Function(String password);

class AccountDeletionPage extends StatefulWidget {
  const AccountDeletionPage({
    super.key,
    this.deletionExecutor,
    this.localCleanup,
  });

  final AccountDeletionExecutor? deletionExecutor;
  final Future<void> Function()? localCleanup;

  @override
  State<AccountDeletionPage> createState() => _AccountDeletionPageState();
}

class _AccountDeletionPageState extends State<AccountDeletionPage> {
  static const _confirmationPhrase = '注销账户';

  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _acknowledged = false;
  bool _submitting = false;

  bool get _canSubmit =>
      !_submitting &&
      _acknowledged &&
      _passwordController.text.isNotEmpty &&
      _confirmationController.text.trim() == _confirmationPhrase;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _requestDeletion() async {
    FocusScope.of(context).unfocus();
    if (!_canSubmit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('最后确认'),
        content: const Text('账户注销后无法恢复，聊天关系、动态、空间及个人资料等数据将被永久清除。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('暂不注销'),
          ),
          TextButton(
            key: const Key('final_delete_account_button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '永久注销',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final executor =
          widget.deletionExecutor ??
          const AccountDeletionRepository().deleteAccount;
      final result = await executor(_passwordController.text);
      if (!mounted) return;
      if (!result.isSuccess) {
        _showMessage(result.message);
        return;
      }

      if (widget.localCleanup != null) {
        await widget.localCleanup!();
      } else {
        WebSocketManager().disconnect();
        GlobalUtil().resetSessionState();
        await StorageUtil.purgeDeletedAccountData();
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (error) {
      debugPrint('账户注销失败：$error');
      if (mounted) _showMessage('网络异常，账户未注销，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _impactRow(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: context.appTextSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    height: 1.45,
                    fontSize: 13,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputField({
    required Key key,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
  }) {
    return TextField(
      key: key,
      controller: controller,
      obscureText: obscureText,
      enableSuggestions: !obscureText,
      autocorrect: false,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: context.appTextSecondary),
        filled: true,
        fillColor: context.appSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(title: const Text('账户注销')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 48,
            color: AppColors.danger,
          ),
          const SizedBox(height: 12),
          Text(
            '注销前请确认以下事项',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '此操作立即生效且无法撤销',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.appTextSecondary),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                _impactRow(
                  Icons.groups_outlined,
                  '先处理由你创建的群聊',
                  '请先解散群聊或转让群主，否则账户无法注销。',
                ),
                Divider(height: 1, indent: 54, color: context.appDivider),
                _impactRow(
                  Icons.delete_forever_outlined,
                  '个人数据将永久删除',
                  '好友关系、动态、空间、点评、位置信息和推送设备等数据将被清除。',
                ),
                Divider(height: 1, indent: 54, color: context.appDivider),
                _impactRow(
                  Icons.history_outlined,
                  '对方的历史记录会保留',
                  '其他用户已有的聊天记录不会被代为删除，其中你的身份将显示为“已注销用户”。',
                ),
                Divider(height: 1, indent: 54, color: context.appDivider),
                _impactRow(
                  Icons.no_accounts_outlined,
                  '账号将无法再次登录',
                  '所有设备会退出登录，原账号不能恢复或重新注册。',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          CheckboxListTile(
            key: const Key('account_deletion_acknowledgement'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _acknowledged,
            onChanged: _submitting
                ? null
                : (value) => setState(() => _acknowledged = value ?? false),
            title: const Text('我已阅读并了解账户注销的全部影响'),
          ),
          const SizedBox(height: 8),
          _inputField(
            key: const Key('account_deletion_password_field'),
            controller: _passwordController,
            hintText: '请输入当前登录密码',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _inputField(
            key: const Key('account_deletion_phrase_field'),
            controller: _confirmationController,
            hintText: '请输入“$_confirmationPhrase”确认',
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 50,
            child: FilledButton(
              key: const Key('delete_account_button'),
              onPressed: _canSubmit ? _requestDeletion : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                disabledBackgroundColor: AppColors.danger.withValues(
                  alpha: 0.25,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('确认注销账户'),
            ),
          ),
        ],
      ),
    );
  }
}
