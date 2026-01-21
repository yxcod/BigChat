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
    return (MaterialApp(
      title: "测试Stack",
      home: Scaffold(
        appBar: AppBar(title: Text("测试Stack")),
        body: Stack(
          alignment: Alignment.topLeft,
          children: [
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            Container(
              alignment: Alignment.center,
              height: 200,
              width: 200,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 255, 7, 85),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                "左上",
                style: TextStyle(fontSize: 20, color: Colors.blue),
              ),
            ),
            Positioned(
              left: 200,
              top: 200,
              child: Container(
                alignment: Alignment.center,
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 164, 53, 150),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "右下",
                  style: TextStyle(fontSize: 20, color: Colors.indigoAccent),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
