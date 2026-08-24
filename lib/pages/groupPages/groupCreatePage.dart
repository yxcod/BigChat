import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/gloabl.dart';
import '../../api/getGroupInfoAPI.dart';
import '../../shared/widgets/app_back_button.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({Key? key}) : super(key: key);

  @override
  _GroupCreatePageState createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  GlobalUtil globalUtil = GlobalUtil();
  TextEditingController _groupIdController = TextEditingController();
  TextEditingController _groupNameController = TextEditingController();
  String _groupIdError = '';

  void _validateGroupId(String value) {
    if (value.isEmpty) {
      setState(() {
        _groupIdError = '请输入群聊号';
      });
    } else if (value.length != 6) {
      setState(() {
        _groupIdError = '群聊号必须为6位';
      });
    } else if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      setState(() {
        _groupIdError = '群聊号必须为纯数字';
      });
    } else {
      setState(() {
        _groupIdError = '';
      });
    }
  }

  void _createGroup() async {
    if (_groupIdController.text.isEmpty || _groupNameController.text.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text('请填写群聊号和群聊名称'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (_groupIdError.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text(_groupIdError),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          );
        },
      );
      return;
    }

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('创建群聊'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('正在创建群聊...'),
            ],
          ),
        );
      },
    );

    try {
      // 检查 userName 是否为空
      if (globalUtil.userName == null) {
        // 关闭加载对话框
        Navigator.pop(context);

        // 显示错误提示
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('错误'),
              content: Text('用户信息未初始化，请重新登录'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('确定'),
                ),
              ],
            );
          },
        );
        return;
      }

      // 调用 createGroup 函数创建群聊
      int code = await createGroup(
        globalUtil.userName!,
        _groupNameController.text,
        int.parse(_groupIdController.text),
      );

      // 关闭加载对话框
      Navigator.pop(context);

      if (code == 100) {
        // 创建成功
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('成功'),
              content: Text('群聊创建成功！'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text('确定'),
                ),
              ],
            );
          },
        );
      } else if (code == 102) {
        // 群 ID 重复
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('提示'),
              content: Text('群聊号已存在，请更换其他群聊号'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('确定'),
                ),
              ],
            );
          },
        );
      } else {
        // 其他错误
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('提示'),
              content: Text('创建群聊失败，请稍后重试'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('确定'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // 关闭加载对话框
      Navigator.pop(context);

      // 显示错误提示
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('错误'),
            content: Text('创建群聊失败，请稍后重试'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('确定'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('创建群聊'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: const AppBackButton(),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5, color: Color(0xFFE5E5E5)),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 群聊号输入
            Container(
              margin: EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '群聊号',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.0),
                  TextField(
                    controller: _groupIdController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    onChanged: _validateGroupId,
                    decoration: InputDecoration(
                      hintText: '请输入6位纯数字群聊号',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.blue, width: 1.0),
                      ),
                      errorText: _groupIdError.isNotEmpty
                          ? _groupIdError
                          : null,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 群聊名称输入
            Container(
              margin: EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '群聊名称',
                    style: TextStyle(
                      fontSize: 14.0,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.0),
                  TextField(
                    controller: _groupNameController,
                    decoration: InputDecoration(
                      hintText: '请输入群聊名称',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.0,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.blue, width: 1.0),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 创建按钮
            ElevatedButton(
              onPressed: _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: Size(double.infinity, 48.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text(
                '创建',
                style: TextStyle(fontSize: 16.0, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
