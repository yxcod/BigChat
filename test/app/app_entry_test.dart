import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/main.dart';

void main() {
  testWidgets('应用只创建一个 MaterialApp 并显示登录页', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('登录'), findsWidgets);
  });
}
