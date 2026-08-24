import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/shared/widgets/app_back_button.dart';

void main() {
  testWidgets('AppBackButton uses a chevron and keeps its tap action', (
    tester,
  ) async {
    var pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: AppBackButton(onPressed: () => pressed = true),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    await tester.tap(find.byType(AppBackButton));
    expect(pressed, isTrue);
  });
}
