import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';
import '../../shared/widgets/user_agreement_dialog.dart';
import '../../utils/WebSocketManager.dart';
import '../../utils/gloabl.dart';
import '../../features/privacy/application/privacy_settings_service.dart';
import '../../utils/http.dart';
import '../../utils/storageUtil.dart';
import 'forgot_password_page.dart';

typedef LoginHandler =
    Future<dynamic> Function(String userName, String password);

void main() {
  runApp(const MaterialApp(home: BigchatLoginPage()));
}

class BigchatLoginPage extends StatefulWidget {
  const BigchatLoginPage({super.key, this.loginHandler});

  final LoginHandler? loginHandler;

  @override
  State<BigchatLoginPage> createState() => _BigchatLoginPageState();
}

class _BigchatLoginPageState extends State<BigchatLoginPage> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _agreementAccepted = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<dynamic> _requestLogin(String userName, String password) async {
    try {
      final response = await HttpUtil().post(
        '/api/user/login',
        data: {'userName': userName, 'password': password},
      );
      return response.data;
    } on DioException catch (error) {
      debugPrint('登录请求失败：${error.error}');
      throw Exception(error.error);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _initializeWebSocket() {
    final userName = GlobalUtil().userName;
    if (userName == null) {
      debugPrint('ERROR: 无法建立WebSocket连接，用户名为空');
      return;
    }
    WebSocketManager().connect(GlobalUtil().getChatWebSocketURL(userName));
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;

    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (phone.isEmpty || password.isEmpty) {
      _showMessage('请输入账号和密码');
      return;
    }
    if (!_agreementAccepted) {
      _showMessage('请先阅读并同意用户协议');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final handler = widget.loginHandler ?? _requestLogin;
      final loginData = await handler(phone, password);
      if (!mounted) return;

      final token = loginData is Map ? loginData['token'] as String? : null;
      final code = loginData is Map ? loginData['code'] as int? : null;
      debugPrint('状态码：$code');

      if (code == 100) {
        if (token == null || token.trim().isEmpty) {
          throw Exception('服务器未返回有效登录令牌');
        }
        GlobalUtil().userName = phone;
        GlobalUtil().isLoading = true;
        GlobalUtil().token = token;
        await StorageUtil.saveAuthenticatedSession(
          userName: phone,
          token: token,
        );
        await PrivacySettingsService.instance.load(ownerId: phone);
        if (!mounted) return;
        _initializeWebSocket();
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/mainWidget',
          (route) => false,
        );
      } else if (code == 101) {
        _showMessage('密码错误');
      } else if (code == 102) {
        _showMessage('用户不存在');
      } else {
        _showMessage('登录失败，请稍后重试');
      }
    } catch (error) {
      debugPrint('登录异常：$error');
      if (mounted) _showMessage('登录失败，请检查网络连接');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 58,
                ),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(23),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            key: const Key('login_app_icon'),
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '全信',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 32,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 42),
                      _buildLoginCard(),
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          key: const Key('login_submit_button'),
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '登录',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            key: const Key('login_forgot_password_button'),
                            onPressed: () async {
                              final changed = await Navigator.of(context)
                                  .push<bool>(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                              if (!context.mounted || changed != true) return;
                              _showMessage('密码修改成功，请使用新密码登录');
                            },
                            child: const Text('忘记密码'),
                          ),
                          TextButton(
                            key: const Key('login_register_button'),
                            onPressed: () =>
                                Navigator.pushNamed(context, '/registerPage'),
                            child: const Text('注册账号'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 52),
                      _buildAgreement(),
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

  Widget _buildLoginCard() {
    return Container(
      key: const Key('login_form_card'),
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
          _LoginField(
            key: const Key('login_account_field'),
            controller: _phoneController,
            label: '账号',
            hint: '请输入账号',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 56,
            color: context.appDivider,
          ),
          _LoginField(
            key: const Key('login_password_field'),
            controller: _passwordController,
            label: '密码',
            hint: '请输入密码',
            icon: Icons.lock_outline_rounded,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _login(),
            suffix: IconButton(
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
              color: context.appTextSecondary,
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreement() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Checkbox(
          key: const Key('login_agreement_checkbox'),
          value: _agreementAccepted,
          visualDensity: VisualDensity.compact,
          onChanged: (value) =>
              setState(() => _agreementAccepted = value ?? false),
        ),
        Text(
          '我已阅读并同意',
          style: TextStyle(color: context.appTextSecondary, fontSize: 12),
        ),
        TextButton(
          key: const Key('login_user_agreement_link'),
          onPressed: () => showUserAgreementDialog(context),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 2),
          ),
          child: const Text(
            '《用户协议》',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      obscureText: obscureText,
      onSubmitted: onFieldSubmitted,
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
        contentPadding: const EdgeInsets.fromLTRB(0, 20, 14, 13),
      ),
    );
  }
}
