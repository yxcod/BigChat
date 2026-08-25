import 'package:flutter/material.dart';
import 'package:flutter_base/features/moments/data/moments_repository.dart';
import 'package:flutter_base/features/moments/presentation/moment_composer_page.dart';
import 'package:flutter_base/features/location/domain/nearby_place.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('composer publishes text through the repository contract', (
    tester,
  ) async {
    final repository = LocalMomentsRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MomentComposerPage(
                  repository: repository,
                  authorId: 'me',
                  authorName: '小明',
                  authorAvatarUrl: '',
                ),
              ),
            ),
            child: const Text('打开编辑器'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开编辑器'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('moment_content_field')),
      '今天完成了动态页面',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('publish_moment_button')));
    await tester.pumpAndSettle();

    final moments = await repository.fetchOwnMoments('me');
    expect(moments.single.content, '今天完成了动态页面');
    expect(find.text('打开编辑器'), findsOneWidget);
  });

  testWidgets('choosing a location opens a page and keeps the selected POI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MomentComposerPage(
          repository: LocalMomentsRepository(),
          authorId: 'me',
          authorName: '小明',
          authorAvatarUrl: '',
          locationLoader: () async => const NearbyPlacesResult(
            currentCity: '南京市',
            places: [
              NearbyPlace(
                name: '中山东路',
                address: '江苏省南京市玄武区中山东路',
                distanceMeters: 180,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('moment_location_button')));
    await tester.pumpAndSettle();
    expect(find.text('南京市'), findsOneWidget);
    expect(find.text('中山东路'), findsOneWidget);
    await tester.tap(find.text('中山东路'));
    await tester.pumpAndSettle();

    expect(find.text('中山东路'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
