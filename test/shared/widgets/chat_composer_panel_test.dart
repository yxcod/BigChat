import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/chat_composer_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app({required bool moreActionsVisible}) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
        child: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              ChatComposerPanel(
                composer: const SizedBox(key: Key('composer'), height: 46),
                moreActionsVisible: moreActionsVisible,
                moreActions: const SizedBox(
                  key: Key('more_actions'),
                  height: 120,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('collapsed composer stays above the device bottom safe area', (
    tester,
  ) async {
    await tester.pumpWidget(app(moreActionsVisible: false));

    final screenBottom = tester.getBottomLeft(find.byType(Scaffold)).dy;
    final composerBottom = tester
        .getBottomLeft(find.byKey(const Key('composer')))
        .dy;
    expect(screenBottom - composerBottom, 34);
  });

  testWidgets('expanded actions remain directly below the composer', (
    tester,
  ) async {
    await tester.pumpWidget(app(moreActionsVisible: true));

    final composerBottom = tester
        .getBottomLeft(find.byKey(const Key('composer')))
        .dy;
    final actionsTop = tester
        .getTopLeft(find.byKey(const Key('more_actions')))
        .dy;
    expect(composerBottom, actionsTop);
  });
}
