import 'dart:io';

import 'package:flutter_base/features/moments/data/moments_local_storage.dart';
import 'package:flutter_base/features/moments/data/moments_repository.dart';
import 'package:flutter_base/features/moments/domain/moment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository restores moments from local storage', () async {
    final storage = InMemoryMomentsStorage();
    final firstRepository = LocalMomentsRepository(storage: storage);
    await firstRepository.publish(_draft('持久化动态'));

    final restoredRepository = LocalMomentsRepository(storage: storage);
    final moments = await restoredRepository.fetchOwnMoments('me');

    expect(moments.single.content, '持久化动态');
  });

  test('file storage safely persists and restores moment JSON', () async {
    final directory = await Directory.systemTemp.createTemp('moments-test-');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final storage = FileMomentsStorage(
      directoryProvider: () async => directory,
    );
    final repository = LocalMomentsRepository(storage: storage);
    await repository.publish(_draft('磁盘动态'));

    final restored = LocalMomentsRepository(storage: storage);
    final moments = await restored.fetchOwnMoments('me');

    expect(moments.single.content, '磁盘动态');
    expect(moments.single.visibility, MomentVisibility.friendsOnly);
  });
}

MomentDraft _draft(String content) {
  return MomentDraft(
    authorId: 'me',
    authorName: '小明',
    authorAvatarUrl: '',
    content: content,
    mediaPaths: const ['https://example.test/image.jpg'],
    visibility: MomentVisibility.friendsOnly,
    location: '上海',
  );
}
