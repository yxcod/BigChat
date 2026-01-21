import 'package:flutter/material.dart';
// import '../pages/profileEditPage.dart';

void main() {
  runApp(FriendAddManagerDemo());
}

class FriendAddManagerDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '好友验证管理',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFFF5F5F5),
      ),
      //home: ProfileEditPage(),
    );
  }
}
