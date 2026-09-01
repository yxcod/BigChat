import 'package:flutter/material.dart';
import 'package:flutter_base/shared/widgets/app_video_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('local video preview displays upload percentage in the bubble', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppVideoPreview(
            source: '',
            isLocal: true,
            uploadProgress: 0.42,
          ),
        ),
      ),
    );

    expect(find.text('42%'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
  });

  testWidgets('failed local video preview is not playable', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppVideoPreview(source: '', isLocal: true, uploadFailed: true),
        ),
      ),
    );

    expect(find.text('发送失败'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AppVideoPreview),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AppVideoPlayerPage), findsNothing);
  });

  testWidgets('completed upload reveals the local video cover', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppVideoPreview(source: '', isLocal: true, uploadProgress: 1),
        ),
      ),
    );

    expect(find.text('100%'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('privacy video keeps saving disabled in the player', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppVideoPreview(source: '', allowSave: false)),
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(AppVideoPreview),
        matching: find.byType(InkWell),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final page = tester.widget<AppVideoPlayerPage>(
      find.byType(AppVideoPlayerPage),
    );
    expect(page.allowSave, isFalse);
  });
}
