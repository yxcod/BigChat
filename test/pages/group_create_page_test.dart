import 'package:flutter/material.dart';
import 'package:flutter_base/pages/groupPages/groupCreatePage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('group creation chrome uses one color and a thin divider', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GroupCreatePage()));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final appBar = tester.widget<AppBar>(find.byType(AppBar));

    expect(scaffold.backgroundColor, Colors.white);
    expect(appBar.backgroundColor, Colors.white);
    expect(appBar.surfaceTintColor, Colors.white);
    expect(appBar.elevation, 0);
    expect(appBar.scrolledUnderElevation, 0);
    expect(appBar.systemOverlayStyle?.statusBarColor, Colors.white);
    expect(appBar.systemOverlayStyle?.statusBarIconBrightness, Brightness.dark);
    expect(appBar.bottom?.preferredSize.height, 0.5);

    final divider = tester.widget<Divider>(find.byType(Divider));
    expect(divider.height, 0.5);
    expect(divider.thickness, 0.5);
  });
}
