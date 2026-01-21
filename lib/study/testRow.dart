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
      title: "测试线形布局ROW",
      home: Scaffold(
        appBar: AppBar(title: Text("布局Row")),
        body: Container(
          color: Colors.blue,
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          child: Flex(
            direction: Axis.vertical,
            children: List.generate(4, (int index) {
              return Container(
                alignment: Alignment.center,
                margin: EdgeInsets.all(30),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(30),
                  color: const Color.fromARGB(255, 33, 240, 243),
                  width: 50,
                  height: 50,
                  child: Text("第${index + 1}项"),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
