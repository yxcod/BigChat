import 'package:flutter/material.dart';
import 'package:flutter_base/features/moments/data/moments_repository.dart';
import 'package:flutter_base/features/moments/domain/moment.dart';
import 'package:flutter_base/features/moments/presentation/my_moments_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('page displays only the current user moments', (tester) async {
    final repository = LocalMomentsRepository();
    await repository.publish(_draft('me', '我的旅行记录'));
    await repository.publish(_draft('friend', '好友不应出现'));

    await tester.pumpWidget(
      MaterialApp(
        home: MyMomentsPage(
          repository: repository,
          userId: 'me',
          displayName: '小明',
          avatarUrl: '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的旅行记录'), findsOneWidget);
    expect(find.text('好友不应出现'), findsNothing);
    expect(find.byIcon(Icons.camera_alt_outlined), findsNothing);
    expect(find.byKey(const Key('moment_publish_fab')), findsOneWidget);
  });

  testWidgets('page supports liking an own moment', (tester) async {
    final repository = LocalMomentsRepository();
    final moment = await repository.publish(_draft('me', '值得点赞'));

    await tester.pumpWidget(
      MaterialApp(
        home: MyMomentsPage(
          repository: repository,
          userId: 'me',
          displayName: '小明',
          avatarUrl: '',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final likeButton = find.byKey(ValueKey('like-${moment.id}'));
    await tester.ensureVisible(likeButton);
    await tester.pumpAndSettle();
    await tester.tap(likeButton);
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('comment sheet submits without disposing active dependencies', (
    tester,
  ) async {
    final repository = LocalMomentsRepository();
    final moment = await repository.publish(_draft('me', '等待评论'));

    await tester.pumpWidget(
      MaterialApp(
        home: MyMomentsPage(
          repository: repository,
          userId: 'me',
          displayName: '小明',
          avatarUrl: '',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final commentButton = find.byKey(ValueKey('comment-${moment.id}'));
    await tester.ensureVisible(commentButton);
    await tester.pumpAndSettle();
    await tester.tap(commentButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('moment_comment_field')),
      '这是一条评论',
    );
    await tester.tap(find.widgetWithText(FilledButton, '发送'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('这是一条评论'), findsOneWidget);
  });

  testWidgets('empty page provides a clear creation entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyMomentsPage(
          repository: LocalMomentsRepository(),
          userId: 'me',
          displayName: '小明',
          avatarUrl: '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('moments_empty_state')), findsOneWidget);
    expect(find.text('发布第一条动态'), findsOneWidget);
  });

  testWidgets('friend space displays moments without publishing controls', (
    tester,
  ) async {
    final repository = LocalMomentsRepository();
    await repository.publish(_draft('friend', '朋友的公开记录'));

    await tester.pumpWidget(
      MaterialApp(
        home: MyMomentsPage(
          repository: repository,
          userId: 'friend',
          displayName: '小李',
          avatarUrl: '',
          allowPublishing: false,
          pageTitle: '小李的空间',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('小李的空间'), findsOneWidget);
    expect(find.text('朋友的公开记录'), findsOneWidget);
    expect(find.byKey(const Key('moment_publish_fab')), findsNothing);
  });

  testWidgets('friend moment media offers a bottom save action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = LocalMomentsRepository();
    await repository.publish(
      const MomentDraft(
        authorId: 'friend',
        authorName: '小李',
        authorAvatarUrl: '',
        content: '带照片的动态',
        mediaPaths: ['https://example.com/moment.jpg'],
        visibility: MomentVisibility.public,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MyMomentsPage(
          repository: repository,
          userId: 'friend',
          displayName: '小李',
          avatarUrl: '',
          allowPublishing: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = find.byKey(const ValueKey('moment_image_0'));
    tester.widget<GestureDetector>(image).onLongPress?.call();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('save_moment_media')), findsOneWidget);
    expect(find.text('保存到本地'), findsOneWidget);
  });

  testWidgets('owner can confirm and permanently remove a moment', (
    tester,
  ) async {
    final repository = LocalMomentsRepository();
    final moment = await repository.publish(_draft('me', '需要删除的动态'));

    await tester.pumpWidget(
      MaterialApp(
        home: MyMomentsPage(
          repository: repository,
          userId: 'me',
          displayName: '小明',
          avatarUrl: '',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final menuButton = find.byKey(ValueKey('moment-menu-${moment.id}'));
    await tester.ensureVisible(menuButton);
    await tester.pumpAndSettle();
    await tester.tap(menuButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除动态'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete_moment_button')));
    await tester.pumpAndSettle();

    expect(find.text('需要删除的动态'), findsNothing);
    expect(await repository.fetchOwnMoments('me'), isEmpty);
  });
}

MomentDraft _draft(String authorId, String content) {
  return MomentDraft(
    authorId: authorId,
    authorName: authorId,
    authorAvatarUrl: '',
    content: content,
    mediaPaths: const [],
    visibility: MomentVisibility.public,
  );
}
