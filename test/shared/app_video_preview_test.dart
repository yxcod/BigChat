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
    await tester.tap(find.byType(AppVideoPreview));
    await tester.pump();
    expect(find.byType(AppVideoPlayerPage), findsNothing);
  });
}
