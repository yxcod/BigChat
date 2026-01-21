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
      title: "测试listView",
      home: Scaffold(
        appBar: AppBar(title: Text("测试ListView")),
        body: ListView.separated(
          itemCount: 100,
          itemBuilder: (BuildContext context, int index) {
            return Container(
              margin: EdgeInsets.only(right: 300, bottom: 0),
              padding: EdgeInsets.all(10),
              alignment: Alignment.center,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text("第${index + 1}项"),
            );
          },
          separatorBuilder: (BuildContext context, int index) {
            return Container(
              margin: EdgeInsets.only(right: 300, bottom: 0),
              height: 10,
              color: Colors.red,
            );
          },
        ),
      ),
    );
  }
}
