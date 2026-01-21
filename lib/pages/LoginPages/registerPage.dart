import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../utils/http.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

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
  Future<dynamic> register(String userName, String password) async {
    try {
      Response response = await HttpUtil().post(
        '/api/user/register',
        data: {'userName': userName, 'password': password},
      );
      debugPrint('POST请求成功：${response.data}');
      // 返回response.data（已经是JSON格式）
      return response.data;
    } on DioException catch (e) {
      debugPrint('POST请求失败：${e.error}');
      // 抛出异常或返回错误信息
      throw Exception(e.error);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入手机号';
    }
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return '请输入有效的手机号';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    if (value.length < 6) {
      return '密码长度不能少于6位';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return '请确认密码';
    }
    if (value != _passwordController.text) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isRegistering = true;
      });
      String phone = _phoneController.text.trim();
      String password = _passwordController.text.trim();
      // 使用异步方式处理登录请求
      Future.delayed(Duration(seconds: 0), () async {
        try {
          if (!mounted) return;
          // 等待login函数执行完成，获取后端返回值
          dynamic loginData = await register(phone, password);
          if (!mounted) return;
          setState(() {});
          if (loginData != null) {
            _isRegistering = false;
            int? code = loginData['code'];
            //注册成功
            if (code == 100) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('注册成功'), duration: Duration(seconds: 2)),
              );
              // 注册成功后返回登陆界面
              Navigator.popAndPushNamed(context, "/login");
            }
            //用户已存在
            else if (code == 101) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('用户已存在'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } catch (error) {
          if (mounted) {
            setState(() {});
            debugPrint('注册异常：$error');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('注册失败：$error'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账号注册'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: '手机号',
                  hintText: '请输入手机号码',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: '密码',
                  hintText: '请输入密码（不少于6位）',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: '确认密码',
                  hintText: '请再次输入密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                  border: const OutlineInputBorder(),
                ),
                validator: _validateConfirmPassword,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isRegistering ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: _isRegistering
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('注册'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
