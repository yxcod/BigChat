import 'package:flutter/material.dart';

void main() {
  runApp(TestRow());
}

class TestRow extends StatefulWidget {
  @override
  _TestRowState createState() => _TestRowState();
}

class _TestRowState extends State<TestRow> {
  @override
  Widget build(BuildContext context) {
    return UnStateWidget();
  }
}

class UnStateWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "测试GridView",
      home: Scaffold(
        appBar: AppBar(title: Text("测试GridView")),
        body: GridView.builder(
          padding: EdgeInsets.all(10),
          //按列排放4个
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: 50,
          itemBuilder: (BuildContext context, int index) {
            return Container(
              color: Colors.amber,
              child: Text("第${index + 1}个"),
            );
          },
        ),
      ),
    );
  }
}
