import 'package:flutter/material.dart';
import 'package:flutter_base/pages/friendManage/friendDetailPage.dart';

// 快速集成测试
class IntegratedTest extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '好友详情页集成测试',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Color(0xFFF8F8F8),
      ),
      home: TestHomePage(),
    );
  }
}

class TestHomePage extends StatelessWidget {
  final List<Map<String, dynamic>> testFriends = [
    {
      'avatar': '😀',
      'remark': '张三',
      'nickname': '小张三',
      'wechatId': 'wx_zhangsan',
      'region': '北京',
    },
    {
      'avatar': '😊',
      'remark': '李四',
      'nickname': '小李四',
      'wechatId': 'wx_lisi',
      'region': '上海',
    },
    {
      'avatar': '😂',
      'remark': '王五',
      'nickname': '小王五',
      'wechatId': 'wx_wangwu',
      'region': '广州',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('好友详情页集成测试'), backgroundColor: Colors.white),
      body: ListView.builder(
        itemCount: testFriends.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              child: Text(testFriends[index]['avatar']),
              backgroundColor: Colors.grey[200],
            ),
            title: Text(testFriends[index]['remark']),
            subtitle: Text('微信号: ${testFriends[index]['wechatId']}'),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      FriendDetailPage(friendData: testFriends[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 独立运行的主函数
void main() {
  runApp(IntegratedTest());
}
