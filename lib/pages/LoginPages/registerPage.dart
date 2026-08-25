import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';
import '../../utils/http.dart';

typedef RegisterHandler =
    Future<dynamic> Function(String userName, String password);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.registerHandler});

  final RegisterHandler? registerHandler;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isRegistering = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<dynamic> _requestRegister(String userName, String password) async {
    try {
      final response = await HttpUtil().post(
        '/api/user/register',
        data: {'userName': userName, 'password': password},
      );
      return response.data;
    } on DioException catch (error) {
      debugPrint('注册请求失败：${error.error}');
      throw Exception(error.error);
    }
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return '请输入手机号';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) return '请输入有效的手机号';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return '请输入密码';
    if (value.length < 6) return '密码长度不能少于6位';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return '请确认密码';
    if (value != _passwordController.text) return '两次输入的密码不一致';
    return null;
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false) || _isRegistering) return;

    setState(() => _isRegistering = true);
    try {
      final handler = widget.registerHandler ?? _requestRegister;
      final result = await handler(
        _phoneController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;

      final code = result is Map ? result['code'] : null;
      if (code == 100) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('注册成功，请登录')));
        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      } else if (code == 101) {
        _showMessage('该账号已注册');
      } else if (code == 103) {
        _showMessage('账号资料初始化失败，请稍后重试');
      } else {
        _showMessage('注册失败，请稍后重试');
      }
    } catch (error) {
      if (mounted) _showMessage('注册失败，请检查网络连接');
      debugPrint('注册异常：$error');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _returnToLogin() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
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
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            key: const Key('register_back_button'),
                            onPressed: _returnToLogin,
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            iconSize: 34,
                            color: context.appTextPrimary,
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _RegisterBrandMark(),
                        const SizedBox(height: 22),
                        Text(
                          '创建账号',
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
                          '填写信息，开始使用全信',
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
                            key: const Key('register_submit_button'),
                            onPressed: _isRegistering ? null : _register,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isRegistering
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '注册',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 13),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '已有账号？',
                              style: TextStyle(
                                color: context.appTextSecondary,
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              key: const Key('register_login_link'),
                              onPressed: _returnToLogin,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                              ),
                              child: const Text(
                                '立即登录',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: context.appTextSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                            children: const [
                              TextSpan(text: '注册即表示你同意 '),
                              TextSpan(
                                text: '《用户协议》',
                                style: TextStyle(color: AppColors.primary),
                              ),
                              TextSpan(text: ' 和 '),
                              TextSpan(
                                text: '《隐私政策》',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
      key: const Key('register_form_card'),
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
          _RegisterField(
            key: const Key('register_phone_field'),
            controller: _phoneController,
            label: '手机号',
            hint: '请输入手机号',
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: _validatePhone,
          ),
          _RegisterDivider(color: context.appDivider),
          _RegisterField(
            key: const Key('register_password_field'),
            controller: _passwordController,
            label: '密码',
            hint: '至少 6 位字符',
            icon: Icons.lock_outline_rounded,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: _validatePassword,
            suffix: _VisibilityButton(
              visible: _isPasswordVisible,
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
          _RegisterDivider(color: context.appDivider),
          _RegisterField(
            key: const Key('register_confirm_password_field'),
            controller: _confirmPasswordController,
            label: '确认密码',
            hint: '请再次输入密码',
            icon: Icons.lock_outline_rounded,
            obscureText: !_isConfirmPasswordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            validator: _validateConfirmPassword,
            onFieldSubmitted: (_) => _register(),
            suffix: _VisibilityButton(
              visible: _isConfirmPasswordVisible,
              onPressed: () => setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterBrandMark extends StatelessWidget {
  const _RegisterBrandMark();

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
          Icons.chat_bubble_rounded,
          color: Colors.white,
          size: 39,
        ),
      ),
    );
  }
}

class _RegisterField extends StatelessWidget {
  const _RegisterField({
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

class _RegisterDivider extends StatelessWidget {
  const _RegisterDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, indent: 56, color: color);
  }
}

class _VisibilityButton extends StatelessWidget {
  const _VisibilityButton({required this.visible, required this.onPressed});

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      color: context.appTextSecondary,
      icon: Icon(
        visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
      ),
    );
  }
}
