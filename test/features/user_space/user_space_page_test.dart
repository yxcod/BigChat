import 'package:flutter/material.dart';
import 'package:flutter_base/features/moments/data/moments_repository.dart';
import 'package:flutter_base/features/moments/presentation/my_moments_page.dart';
import 'package:flutter_base/features/user_space/data/user_space_repository.dart';
import 'package:flutter_base/features/user_space/domain/user_space.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('owner space exposes owner-only controls and wording', (
    tester,
  ) async {
    final spaceRepository = InMemoryUserSpaceRepository(
      currentUserName: 'owner',
      initialData: const UserSpaceData(ownerUserName: 'owner', isOwner: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MyMomentsPage(
          repository: LocalMomentsRepository(),
          spaceRepository: spaceRepository,
          userId: 'owner',
          displayName: '叶翔',
          avatarUrl: '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的动态'), findsNWidgets(2));
    expect(find.text('我的点评'), findsOneWidget);
    expect(find.byKey(const Key('change_space_cover_button')), findsOneWidget);
    expect(
      find.byKey(const Key('manage_space_messages_button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('leave_space_message_button')), findsNothing);
  });

  testWidgets('visitor leaves a message on a separate editor page', (
    tester,
  ) async {
    final spaceRepository = InMemoryUserSpaceRepository(
      currentUserName: '访客',
      initialData: const UserSpaceData(ownerUserName: 'owner', isOwner: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MyMomentsPage(
          repository: LocalMomentsRepository(),
          spaceRepository: spaceRepository,
          userId: 'owner',
          displayName: '叶翔',
          avatarUrl: '',
          allowPublishing: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('他的动态'), findsNWidgets(2));
    expect(find.text('他的点评'), findsOneWidget);
    expect(find.byKey(const Key('change_space_cover_button')), findsNothing);
    expect(find.byKey(const Key('manage_space_messages_button')), findsNothing);

    await tester.tap(find.byKey(const Key('leave_space_message_button')));
    await tester.pumpAndSettle();
    expect(find.text('发表'), findsOneWidget);
    expect(find.text('给叶翔留言'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('space_message_editor_field')),
      '最近怎么样',
    );
    await tester.tap(find.byKey(const Key('publish_space_message_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('访客: 最近怎么样'), findsOneWidget);
  });
}
