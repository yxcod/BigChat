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
    expect(find.byKey(const Key('moment_compose_button')), findsOneWidget);
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
    await tester.tap(find.byKey(ValueKey('like-${moment.id}')));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
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
