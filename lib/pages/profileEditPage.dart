import 'dart:typed_data';
import 'package:flutter/material.dart';
//必须加载是大写的Gloabl.dart
import '../utils/Gloabl.dart';
import '../api/getInfoAPI.dart';
import '../model/userInfoModel.dart';
import '../utils/WebSocketManager.dart';

class ProfileEditPage extends StatefulWidget {
  final Map<String, dynamic>? profileInfo;
  const ProfileEditPage({super.key, required this.profileInfo});
  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _nicknameController = TextEditingController();
  final _signatureController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String _nickName = "";
  String _signature = "";
  bool _shouldRefreshAvatar = false; // 标记是否需要刷新头像
  @override
  void initState() {
    super.initState();
    if (widget.profileInfo != null) {
      _nickName = widget.profileInfo!['nickName']?.toString() ?? '';
      _signature = widget.profileInfo!['signature']?.toString() ?? '';
      _nicknameController.text = _nickName;
      _signatureController.text = _signature;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _signatureController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 构建带有时间戳的头像URL
  String _buildAvatarUrl() {
    final String baseUrl = GlobalUtil().getImageURL(
      GlobalUtil().userName ?? "",
      "head.jpg",
    );
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return _shouldRefreshAvatar
        ? (baseUrl.contains('?')
              ? '$baseUrl&t=$timestamp'
              : '$baseUrl?t=$timestamp')
        : baseUrl;
  }

  // 修改头像
  Future<void> _changeAvatar() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 调用GlobalUtil的selectAndUploadAvatar方法
      final Uint8List? imageData = await GlobalUtil().selectAndUploadAvatar(
        "head.jpg",
      );

      if (imageData != null) {
        // 头像上传成功，标记需要刷新头像
        setState(() {
          _shouldRefreshAvatar = true;
        });
        _showMessage('头像修改成功');
      } else {
        // 用户取消了选择或上传失败
        _showMessage('头像修改取消或失败');
      }
    } catch (e) {
      debugPrint('修改头像失败：$e');
      _showMessage('头像修改失败，请稍后重试');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 显示修改密码弹窗
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('修改密码'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currentPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '当前密码',
                    hintText: '请输入当前密码',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '新密码',
                    hintText: '请输入新密码',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '确认密码',
                    hintText: '请再次输入新密码',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _changePassword();
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 修改密码
  void _changePassword() async {
    // 获取输入的密码
    final String currentPassword = _currentPasswordController.text;
    final String newPassword = _newPasswordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    // 验证输入
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

    // 显示加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取当前用户名
      final String userName = GlobalUtil().userName ?? '';
      if (userName.isEmpty) {
        _showMessage('无法获取当前用户信息');
        return;
      }

      // 调用修改密码API
      final int code = await changePasswordApi(
        userName,
        currentPassword,
        newPassword,
      );

      // 检查API返回结果
      if (code == 100) {
        // 密码修改成功，清空输入框
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _showMessage('密码修改成功，即将退出登录');
        // 延迟1秒后退出登录
        Future.delayed(Duration(seconds: 1), () {
          _performLogout();
        });
      } else {
        // 密码修改失败
        _showMessage('密码修改失败，请检查当前密码是否正确');
      }
    } catch (e) {
      // 处理异常
      debugPrint('修改密码失败：$e');
      _showMessage('密码修改失败，请稍后重试');
    } finally {
      // 隐藏加载状态
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 执行退出登录
  void _performLogout() {
    // 断开WebSocket连接
    WebSocketManager().disconnect();
    // 这里可以跳转到登录页面
    Navigator.pushReplacementNamed(context, '/login');
  }

  // 显示提示信息
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        toolbarHeight: 50,
        actions: [
          IconButton(
            onPressed: _showChangePasswordDialog,
            icon: Icon(Icons.lock, color: Colors.green),
            tooltip: '修改密码',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像部分
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _changeAvatar,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            _buildAvatarUrl(),
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) {
                                // 图片加载完成后，重置刷新标记
                                if (_shouldRefreshAvatar) {
                                  setState(() {
                                    _shouldRefreshAvatar = false;
                                  });
                                }
                                return child;
                              }
                              return Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('头像加载失败：$error');
                              return Icon(
                                Icons.person,
                                color: Colors.grey[400],
                                size: 40,
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextButton(
                        onPressed: _changeAvatar,
                        child: Text(
                          '点击更换头像',
                          style: TextStyle(color: Colors.blue, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // 昵称部分
                Text('昵称'),
                SizedBox(height: 8),
                TextField(
                  controller: _nicknameController,
                  decoration: InputDecoration(
                    hintText: '请输入昵称',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _nickName = value;
                    });
                  },
                ),
                SizedBox(height: 16),
                // 个性签名部分
                Text('个性签名'),
                SizedBox(height: 8),
                TextField(
                  controller: _signatureController,
                  decoration: InputDecoration(
                    hintText: '请输入个性签名',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                  onChanged: (value) {
                    setState(() {
                      _signature = value;
                    });
                  },
                ),
                SizedBox(height: 24),
                // 保存按钮
                ElevatedButton(
                  onPressed: _saveProfile,
                  child: Text('保存'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 加载遮罩
          if (_isLoading)
            Container(
              color: Color.fromRGBO(0, 0, 0, 0.5),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // 保存个人信息
  void _saveProfile() async {
    // 获取输入的信息
    final String nickName = _nicknameController.text;
    final String signature = _signatureController.text;

    // 验证输入
    if (nickName.isEmpty) {
      _showMessage('请输入昵称');
      return;
    }

    // 显示加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取当前用户信息
      final UserInfoModel currentUserInfo = GlobalUtil().userInfoModel;

      // 更新用户信息
      final String userName = currentUserInfo.userName ?? "";
      debugPrint('yx---userName = $userName');
      final UserInfoModel updatedUserInfo = UserInfoModel(
        userName: currentUserInfo.userName,
        nickName: nickName,
        avatar: currentUserInfo.avatar,
        signature: signature,
        friendListData: currentUserInfo.friendListData,
      );

      // 调用保存个人信息API
      final int code = await updateUserInfoApi(updatedUserInfo);

      // 检查API返回结果
      if (code == 100) {
        // 保存更新后的用户信息到全局变量
        GlobalUtil().userInfoModel = updatedUserInfo;
        // 保存成功
        _showMessage('个人信息保存成功');
        // 返回到上一个页面
        Navigator.pop(context);
      } else {
        // 保存失败
        _showMessage('个人信息保存失败，请稍后重试');
      }
    } catch (e) {
      // 处理异常
      debugPrint('保存个人信息失败：$e');
      _showMessage('个人信息保存失败，请稍后重试');
    } finally {
      // 隐藏加载状态
      setState(() {
        _isLoading = false;
      });
    }
  }
}
