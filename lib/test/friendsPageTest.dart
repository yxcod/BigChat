import 'package:flutter/material.dart';
import '../routes/routeIndex.dart';

class FriendsPageTest extends StatefulWidget {
  @override
  _FriendsPageTestState createState() => _FriendsPageTestState();
}

class _FriendsPageTestState extends State<FriendsPageTest> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('好友页面路由测试')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('测试搜索好友路由功能', style: TextStyle(fontSize: 18)),
            SizedBox(height: 20),

            // 测试按钮1: 直接导航到搜索页面
            ElevatedButton(
              onPressed: () {
                try {
                  Navigator.pushNamed(context, '/searchFriendPage');
                } catch (e) {
                  print('导航错误: $e');
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('导航错误: $e')));
                }
              },
              child: Text('直接导航到搜索好友页面'),
            ),
            SizedBox(height: 10),

            // 测试按钮2: 验证路由是否注册
            ElevatedButton(
              onPressed: () {
                final routes = getRoutes();
                print('注册的路由: ${routes.keys.toList()}');

                if (routes.containsKey('/searchFriendPage')) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('路由已正确注册')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('路由未注册'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text('检查路由注册状态'),
            ),
            SizedBox(height: 10),

            // 测试按钮3: 使用MaterialPageRoute直接导航
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SearchFriendPage()),
                );
              },
              child: Text('使用MaterialPageRoute直接导航'),
            ),
          ],
        ),
      ),
    );
  }
}

// 简单的搜索页面替代类
class SearchFriendPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('搜索好友页面')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.blue),
            SizedBox(height: 16),
            Text('这是搜索好友页面'),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '好友页面路由测试',
      home: FriendsPageTest(),
      routes: {
        '/test': (context) => FriendsPageTest(),
        '/searchFriendPage': (context) => SearchFriendPage(),
      },
    );
  }
}
