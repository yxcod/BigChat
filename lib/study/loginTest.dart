import 'package:flutter/material.dart';

void main() {
  runApp(MainPapage());
}

class MainPapage extends StatefulWidget {
  @override
  _MainPapage createState() => _MainPapage();
}

class _MainPapage extends State<MainPapage> {
  TextEditingController _phoneController = TextEditingController();
  TextEditingController _codeController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "测试登陆界面",
      home: Scaffold(
        appBar: AppBar(title: Text("登陆")),
        body: Container(
          padding: EdgeInsets.all(15),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                controller: _phoneController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.only(left: 20),
                  hintText: "请输入账号",
                  fillColor: const Color.from(
                    alpha: 255,
                    red: 222,
                    green: 219,
                    blue: 209,
                  ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                obscureText: true,
                controller: _codeController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.only(left: 20),
                  hintText: "请输入密码",
                  fillColor: const Color.from(
                    alpha: 255,
                    red: 222,
                    green: 219,
                    blue: 209,
                  ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Container(
                height: 50,
                width: 400,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 72, 1, 126),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextButton(
                  onPressed: () {
                    print(_phoneController.text);
                  },
                  child: Text("登陆", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
