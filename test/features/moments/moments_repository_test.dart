import 'package:flutter_base/features/moments/data/moments_repository.dart';
import 'package:flutter_base/features/moments/domain/moment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'repository only returns moments authored by the requested user',
    () async {
      final repository = LocalMomentsRepository();
      await repository.publish(_draft('me', '我的动态'));
      await repository.publish(_draft('friend', '好友动态'));

      final moments = await repository.fetchOwnMoments('me');

      expect(moments, hasLength(1));
      expect(moments.single.content, '我的动态');
    },
  );

  test('repository updates like and comment state', () async {
    final repository = LocalMomentsRepository();
    final moment = await repository.publish(_draft('me', '今天很好'));

    final liked = await repository.toggleLike(
      momentId: moment.id,
      userId: 'me',
    );
    final commented = await repository.addComment(
      momentId: moment.id,
      userId: 'me',
      displayName: '小明',
      content: '记录一下',
    );

    expect(liked.isLiked, isTrue);
    expect(liked.likeCount, 1);
    expect(commented.comments.single.content, '记录一下');
  });

  test('repository permanently removes only the author own moment', () async {
    final repository = LocalMomentsRepository();
    final moment = await repository.publish(_draft('me', '准备删除'));

    await expectLater(
      repository.deleteMoment(momentId: moment.id, userId: 'friend'),
      throwsStateError,
    );
    await repository.deleteMoment(momentId: moment.id, userId: 'me');

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
