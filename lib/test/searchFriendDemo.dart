import 'package:flutter/material.dart';
import '../pages/friendManage/searchFriendPage.dart';

class SearchFriendDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('搜索好友功能演示'), backgroundColor: Colors.white),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 80, color: Colors.blue),
            SizedBox(height: 24),
            Text(
              '搜索好友功能',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '通过手机号搜索并添加好友',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchFriendPage()),
                );
              },
              icon: Icon(Icons.search),
              label: Text('开始搜索好友'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
            SizedBox(height: 40),

            // 测试数据提示
            Container(
              margin: EdgeInsets.symmetric(horizontal: 32),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '测试数据：',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• 13800138000 - 张三', style: TextStyle(fontSize: 14)),
                  Text('• 13800138001 - 李四', style: TextStyle(fontSize: 14)),
                  Text('• 13800138002 - 王五', style: TextStyle(fontSize: 14)),
                  SizedBox(height: 8),
                  Text(
                    '输入以上任意手机号可以搜索到对应用户',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 完整的演示应用
class SearchFriendDemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '搜索好友功能演示',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
      ),
      home: SearchFriendDemo(),
    );
  }
}

// 使用说明：
// 1. 在其他文件中导入：import '../pages/searchFriendPage.dart';
// 2. 跳转到搜索页面：Navigator.push(context, MaterialPageRoute(builder: (context) => SearchFriendPage()));
// 3. 测试手机号：13800138000, 13800138001, 13800138002
