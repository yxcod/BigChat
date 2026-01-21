import 'package:flutter/material.dart';
import '../pages/friendManage/friendDetailPage.dart';

class FriendDetailDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('好友详情页演示')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // 模拟好友数据
            Map<String, dynamic> friendData = {
              'avatar':
                  'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
              'remark': '张三',
              'nickname': '小明的朋友',
              'wechatId': 'zhangsan123',
              'region': '北京',
            };

            // 跳转到好友详情页面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FriendDetailPage(friendData: friendData),
              ),
            );
          },
          child: Text('查看好友详情页'),
        ),
      ),
    );
  }
}
