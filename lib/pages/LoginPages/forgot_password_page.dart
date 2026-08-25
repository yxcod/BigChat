import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/getInfoAPI.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';

typedef PasswordResetter =
    Future<int> Function(String userName, String newPassword);

String passwordSecurityCodeForDate(DateTime date) {
  final value =
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
  return value.split('').reversed.join();
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.passwordResetter, this.now});

  final PasswordResetter? passwordResetter;
  final DateTime Function()? now;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _securityCodeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _passwordVisible = false;
  bool _submitting = false;

  DateTime get _currentDate => (widget.now ?? DateTime.now).call();

  @override
  void dispose() {
    _accountController.dispose();
    _securityCodeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  String? _validateAccount(String? value) {
    if ((value ?? '').trim().isEmpty) return '请输入账号';
    return null;
  }

  String? _validateSecurityCode(String? value) {
    final input = (value ?? '').trim();
    if (input.isEmpty) return '请输入安全码';
    if (input != passwordSecurityCodeForDate(_currentDate)) {
      return '安全码错误 请联系管理员';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) return '请输入新的密码';
    if (value.length < 6) return '新密码长度不能少于6位';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final resetter = widget.passwordResetter ?? resetPasswordApi;
      final code = await resetter(
        _accountController.text.trim(),
        _newPasswordController.text,
      );
      if (!mounted) return;

      if (code == 100) {
        Navigator.pop(context, true);
      } else if (code == 102) {
        _showMessage('账号不存在，请检查后重试');
      } else {
        _showMessage('密码修改失败，请稍后重试');
      }
    } catch (error) {
      debugPrint('找回密码失败：$error');
      if (mounted) _showMessage('密码修改失败，请检查网络连接');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context, false);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlayStyle = context.isDarkMode
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: context.appPageBackground,
      ),
      child: Scaffold(
        backgroundColor: context.appPageBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 28,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          key: const Key('forgot_password_back_button'),
                          onPressed: _submitting ? null : _close,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          iconSize: 34,
                          color: context.appTextPrimary,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _RecoveryBrandMark(),
                      const SizedBox(height: 22),
                      Text(
                        '找回密码',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '验证身份后设置新的登录密码',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 34),
                      _buildFormCard(),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          key: const Key('forgot_password_submit_button'),
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '确认修改',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '想起密码了？',
                            style: TextStyle(
                              color: context.appTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            key: const Key('forgot_password_login_link'),
                            onPressed: _submitting ? null : _close,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                            ),
                            child: const Text(
                              '返回登录',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      key: const Key('forgot_password_form_card'),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.isDarkMode ? context.appDivider : Colors.transparent,
        ),
        boxShadow: context.isDarkMode
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        children: [
          _RecoveryField(
            key: const Key('forgot_password_account_field'),
            controller: _accountController,
            label: '账号',
            hint: '请输入账号',
            icon: Icons.person_outline_rounded,
            validator: _validateAccount,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
          ),
          _RecoveryDivider(color: context.appDivider),
          _RecoveryField(
            key: const Key('forgot_password_security_code_field'),
            controller: _securityCodeController,
            label: '安全码',
            hint: '请输入8位安全码',
            icon: Icons.verified_user_outlined,
            validator: _validateSecurityCode,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
          ),
          _RecoveryDivider(color: context.appDivider),
          _RecoveryField(
            key: const Key('forgot_password_new_password_field'),
            controller: _newPasswordController,
            label: '新的密码',
            hint: '至少 6 位字符',
            icon: Icons.lock_outline_rounded,
            validator: _validateNewPassword,
            obscureText: !_passwordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _submit(),
            suffix: IconButton(
              onPressed: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
              color: context.appTextSecondary,
              icon: Icon(
                _passwordVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryBrandMark extends StatelessWidget {
  const _RecoveryBrandMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2907C160),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.lock_reset_rounded,
          color: Colors.white,
          size: 43,
        ),
      ),
    );
  }
}

class _RecoveryField extends StatelessWidget {
  const _RecoveryField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.obscureText = false,
    this.suffix,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: TextStyle(color: context.appTextPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          color: context.appTextPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: context.appTextSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 23),
        suffixIcon: suffix,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: const EdgeInsets.fromLTRB(0, 20, 14, 13),
      ),
    );
  }
}

class _RecoveryDivider extends StatelessWidget {
  const _RecoveryDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, indent: 56, color: color);
  }
}
