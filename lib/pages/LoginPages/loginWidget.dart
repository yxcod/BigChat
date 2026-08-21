import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../utils/http.dart';
import '../../utils/gloabl.dart';
import '../../utils/WebSocketManager.dart';

void main() {
  runApp(MaterialApp(home: BigchatLoginPage()));
}

class BigchatLoginPage extends StatefulWidget {
  const BigchatLoginPage({super.key});

  @override
  State<BigchatLoginPage> createState() => _BigchatLoginPageState();
}

class _BigchatLoginPageState extends State<BigchatLoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  Future<dynamic> login(String userName, String password) async {
    try {
      Response response = await HttpUtil().post(
        '/api/user/login',
        data: {'userName': userName, 'password': password},
      );
      //debugPrint('POST请求成功：${response.data}');
      // 返回response.data（已经是JSON格式）
      return response.data;
    } on DioException catch (e) {
      debugPrint('POST请求失败：${e.error}');
      // 抛出异常或返回错误信息
      throw Exception(e.error);
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  // 初始化WebSocket连接
  void _initializeWebSocket() {
    final wsManager = WebSocketManager();
    final userName = GlobalUtil().userName;

    if (userName == null) {
      print('ERROR: 无法建立WebSocket连接，用户名为空');
      return;
    }

    String wsUrl =
        '${GlobalUtil().baseWebSocketURL}/api/chat?userName=$userName';

    // 连接WebSocket，不添加消息监听器（由具体页面添加）
    wsManager.connect(wsUrl);
  }

  void _login() {
    // 登录成功后跳转到主界面，并清除登录页面历史，无法返回
    // Navigator.pushNamedAndRemoveUntil(context, '/mainWidget', (route) => false);
    // return;
    String phone = _phoneController.text.trim();
    String password = _passwordController.text.trim();

    // 移除不必要的延迟，直接异步处理登录
    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入手机号和密码'), duration: Duration(seconds: 2)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 使用异步方式处理登录请求
    Future.delayed(Duration(seconds: 0), () async {
      try {
        if (!mounted) return;
        // 等待login函数执行完成，获取后端返回值
        dynamic loginData = await login(phone, password);
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        if (loginData != null) {
          // 获取token
          String? token = loginData['token'];
          int? code = loginData['code'];
          debugPrint('状态码：${code}');

          //登录成功
          if (code == 100) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('登录成功'), duration: Duration(seconds: 2)),
            );
            //存储当前登录用户
            GlobalUtil().userName = phone;
            GlobalUtil().isLoading = true;
            GlobalUtil().token = token;

            // 初始化WebSocket连接，传入当前用户名
            _initializeWebSocket();

            // 登录成功后跳转到主界面，并清除登录页面历史，无法返回
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/mainWidget',
              (route) => false,
            );
          }
          //密码错误
          else if (code == 101) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('密码错误'), duration: Duration(seconds: 2)),
            );
          }
          //用户不存在
          else if (code == 102) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('用户不存在'), duration: Duration(seconds: 2)),
            );
          }

          debugPrint('获取到token: $token');
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          debugPrint('登录异常：$error');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('登录失败：$error'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Color(0xFFF5F5F7),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 40),
            Text(
              '全信',
              style: TextStyle(
                fontSize: 28.0,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 60),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '请输入手机号',
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                ),
              ),
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 30),
            TextField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                hintText: '请输入密码',
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.green),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: _togglePasswordVisibility,
                ),
              ),
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        '登录',
                        style: TextStyle(fontSize: 18.0, color: Colors.white),
                      ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('忘记密码功能开发中'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text('忘记密码', style: TextStyle(color: Colors.green)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/registerPage');
                  },
                  child: Text('注册', style: TextStyle(color: Colors.green)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
