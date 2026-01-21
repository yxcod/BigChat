import 'package:flutter/material.dart';

void main() {
  runApp(MainPapage());
}

class unStaetWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "测试页面",
      theme: ThemeData(
        scaffoldBackgroundColor: const Color.fromARGB(0, 251, 87, 87),
      ),
      home: Scaffold(
        appBar: AppBar(title: Text("标题文字")),
        body: Container(child: Center(child: Text("中间区域"))),
        bottomNavigationBar: Container(
          height: 50,
          child: Center(child: Text("底部区域")),
        ),
      ),
    );
  }
}

class MainPapage extends StatefulWidget {
  @override
  _MainPapage createState() => _MainPapage();
}

class _MainPapage extends State<MainPapage> {
  @override
  Widget build(BuildContext context) {
    return unStaetWidget();
  }
}
