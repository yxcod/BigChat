import 'package:flutter/material.dart';
import 'package:flutter_base/features/moments/data/moments_repository.dart';
import 'package:flutter_base/features/moments/domain/moment.dart';
import 'package:flutter_base/pages/friendManage/friendDetailPage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile previews at most six photos and opens friend space', (
    tester,
  ) async {
    final repository = LocalMomentsRepository();
    await repository.publish(
      const MomentDraft(
        authorId: 'friend',
        authorName: '小李',
        authorAvatarUrl: '',
        content: '最近一条动态',
        mediaPaths: [
          'https://example.com/1.jpg',
          'https://example.com/2.jpg',
          'https://example.com/3.jpg',
          'https://example.com/4.jpg',
          'https://example.com/5.jpg',
          'https://example.com/6.jpg',
          'https://example.com/7.jpg',
        ],
        visibility: MomentVisibility.public,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FriendDetailPage(
          friendData: {
            'userName': 'friend',
            'nickname': '小李',
            'avatar': '',
            'isFriend': true,
          },
          momentsRepository: repository,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'friend_moment_preview_image_',
            ),
      ),
      findsNWidgets(6),
    );

    await tester.tap(find.byKey(const Key('friend_moments_section')));
    await tester.pumpAndSettle();

    expect(find.text('小李的空间'), findsOneWidget);
    expect(find.text('最近一条动态'), findsOneWidget);
    expect(find.byKey(const Key('moment_publish_fab')), findsNothing);
  });
}
