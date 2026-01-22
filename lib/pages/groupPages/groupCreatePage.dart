import 'package:flutter/material.dart';
import '../../utils/gloabl.dart';

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

  void _createGroup() {
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

    // 实现创建群聊的逻辑
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('创建群聊'),
          content: Text('确定要创建群聊吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                // 这里可以添加创建群聊的逻辑
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('创建群聊'),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
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
                        borderSide: BorderSide(
                          color: Colors.blue,
                          width: 1.0,
                        ),
                      ),
                      errorText: _groupIdError.isNotEmpty ? _groupIdError : null,
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
                        borderSide: BorderSide(
                          color: Colors.blue,
                          width: 1.0,
                        ),
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
