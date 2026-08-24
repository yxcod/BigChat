import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../utils/gloabl.dart';
import '../api/getInfoAPI.dart';
import '../model/userInfoModel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/cache/app_image_cache.dart';
import 'change_password_page.dart';

class ProfileEditPage extends StatefulWidget {
  final Map<String, dynamic>? profileInfo;
  const ProfileEditPage({super.key, required this.profileInfo});
  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _nicknameController = TextEditingController();
  final _signatureController = TextEditingController();

  bool _isLoading = false;
  String _nickName = "";
  String _signature = "";
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
    super.dispose();
  }

  // 头像文件名是缓存版本；文件名变化时会自动下载新头像。
  String _buildAvatarUrl() {
    String avatarName = GlobalUtil().userInfoModel.avatar ?? "head.jpg";
    return GlobalUtil().getImageURL(GlobalUtil().userName ?? "", avatarName);
  }

  // 修改头像
  Future<void> _changeAvatar() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 生成带时间戳的头像文件名
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String avatarFileName = "head_$timestamp.jpg";

      // 调用GlobalUtil的selectAndUploadAvatar方法
      final Uint8List? imageData = await GlobalUtil().selectAndUploadAvatar(
        avatarFileName,
      );

      if (imageData != null) {
        // 头像上传成功，更新用户信息中的头像名
        final UserInfoModel currentUserInfo = GlobalUtil().userInfoModel;
        final UserInfoModel updatedUserInfo = UserInfoModel(
          userName: currentUserInfo.userName,
          nickName: currentUserInfo.nickName,
          avatar: avatarFileName,
          signature: currentUserInfo.signature,
          friendListData: currentUserInfo.friendListData,
        );

        // 调用保存个人信息API更新头像名
        final int code = await updateUserInfoApi(updatedUserInfo);

        if (code == 100) {
          // 保存更新后的用户信息到全局变量
          GlobalUtil().userInfoModel = updatedUserInfo;
          setState(() {});
          _showMessage('头像修改成功');
        } else {
          _showMessage('头像修改失败，请稍后重试');
        }
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

  void _openChangePasswordPage() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const ChangePasswordPage()),
    );
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
            key: const Key('open_change_password_page'),
            onPressed: _openChangePasswordPage,
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
                          child: CachedNetworkImage(
                            cacheManager: AppImageCache.manager,
                            imageUrl: _buildAvatarUrl(),
                            cacheKey: AppImageCache.cacheKey(_buildAvatarUrl()),
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            progressIndicatorBuilder:
                                (context, url, progress) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: progress.progress,
                                  ),
                                ),
                            errorWidget: (context, url, error) {
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
