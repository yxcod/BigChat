import 'package:flutter_base/features/moments/data/moments_local_storage.dart';
import 'package:flutter_base/features/moments/data/server_moments_repository.dart';
import 'package:flutter_base/features/moments/domain/moment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads server moments and parses milliseconds and visibility', () async {
    final api = _FakeMomentsApi((path, data) async {
      expect(path, '/api/moment/ownList');
      expect(data['limit'], 50);
      return {
        'code': 100,
        'data': {
          'items': [
            {
              'id': 12,
              'authorId': 'me',
              'authorName': '小明',
              'authorAvatarUrl': '',
              'content': '服务端动态',
              'mediaPaths': <String>[],
              'createdAt': 1700000000000,
              'visibility': 1,
              'location': null,
              'likeCount': 2,
              'isLiked': true,
              'comments': <Map<String, dynamic>>[],
            },
          ],
        },
      };
    });
    final repository = ServerMomentsRepository(
      apiClient: api,
      cache: _ReadOnlyMomentsStorage(),
    );

    final moments = await repository.fetchOwnMoments('me');

    expect(moments.single.id, '12');
    expect(moments.single.visibility, MomentVisibility.friendsOnly);
    expect(moments.single.createdAt.millisecondsSinceEpoch, 1700000000000);
  });

  test('publishes uploaded media URLs with an idempotency key', () async {
    late Map<String, dynamic> requestData;
    final api = _FakeMomentsApi((path, data) async {
      expect(path, '/api/moment/publish');
      requestData = data;
      return {'code': 100, 'data': _momentJson(id: 21, content: '新动态')};
    });
    final repository = ServerMomentsRepository(
      apiClient: api,
      cache: _ReadOnlyMomentsStorage(),
    );

    final moment = await repository.publish(
      const MomentDraft(
        authorId: 'me',
        authorName: '小明',
        authorAvatarUrl: '',
        content: ' 新动态 ',
        mediaPaths: ['https://example.com/image.jpg'],
        visibility: MomentVisibility.private,
      ),
    );

    expect(moment.id, '21');
    expect(requestData['content'], '新动态');
    expect(requestData['visibility'], 2);
    expect(requestData['mediaUrls'], ['https://example.com/image.jpg']);
    expect(requestData['clientRequestId'], startsWith('me-'));
  });

  test(
    'publishes and restores a video thumbnail with durable local paths',
    () async {
      const videoUrl = 'https://example.com/video.mp4';
      const thumbnailUrl = 'https://example.com/video-cover.jpg';
      late Map<String, dynamic> requestData;
      final cache = _ReadOnlyMomentsStorage();
      final api = _FakeMomentsApi((path, data) async {
        requestData = data;
        return {
          'code': 100,
          'data': {
            ..._momentJson(id: 22, content: '视频动态'),
            'mediaPaths': [videoUrl],
            'mediaItems': [
              {'url': videoUrl, 'type': 'video', 'thumbnailUrl': thumbnailUrl},
            ],
          },
        };
      });
      final repository = ServerMomentsRepository(apiClient: api, cache: cache);

      final moment = await repository.publish(
        const MomentDraft(
          authorId: 'me',
          authorName: '小明',
          authorAvatarUrl: '',
          content: '视频动态',
          mediaPaths: [videoUrl],
          mediaThumbnailUrls: {videoUrl: thumbnailUrl},
          localMediaPaths: {videoUrl: '/local/video.mp4'},
          localThumbnailPaths: {videoUrl: '/local/video.jpg'},
          visibility: MomentVisibility.public,
        ),
      );

      expect(requestData['mediaUrls'], [
        {'url': videoUrl, 'thumbnailUrl': thumbnailUrl},
      ]);
      expect(moment.mediaThumbnails[videoUrl], thumbnailUrl);
      expect(moment.localMediaPaths[videoUrl], '/local/video.mp4');
      expect(
        (await cache.load()).single.localThumbnailPaths[videoUrl],
        '/local/video.jpg',
      );
    },
  );

  test(
    'server refresh keeps local video mappings for unchanged media',
    () async {
      const videoUrl = 'https://example.com/video.mp4';
      final cached = Moment.fromJson({
        ..._momentJson(id: 23, content: '缓存视频'),
        'mediaPaths': [videoUrl],
        'localMediaPaths': {videoUrl: '/local/video.mp4'},
      });
      final cache = _ReadOnlyMomentsStorage([cached]);
      final repository = ServerMomentsRepository(
        apiClient: _FakeMomentsApi(
          (_, _) async => {
            'code': 100,
            'data': {
              'items': [
                {
                  ..._momentJson(id: 23, content: '缓存视频'),
                  'mediaPaths': [videoUrl],
                },
              ],
            },
          },
        ),
        cache: cache,
      );

      final moments = await repository.fetchOwnMoments('me');

      expect(moments.single.localMediaPaths[videoUrl], '/local/video.mp4');
    },
  );

  test('loads moments visible to the current user from a profile', () async {
    late Map<String, dynamic> requestData;
    final api = _FakeMomentsApi((path, data) async {
      expect(path, '/api/moment/userList');
      requestData = data;
      return {
        'code': 100,
        'data': {
          'items': [_momentJson(id: 31, content: '好友公开动态')],
        },
      };
    });
    final repository = ServerMomentsRepository(
      apiClient: api,
      cache: InMemoryMomentsStorage(),
    );

    final moments = await repository.fetchUserMoments('me');

    expect(requestData['targetUserName'], 'me');
    expect(requestData['limit'], 50);
    expect(moments.single.content, '好友公开动态');
  });

  test('loads every visible profile page using the moment cursor', () async {
    var callCount = 0;
    final api = _FakeMomentsApi((path, data) async {
      callCount += 1;
      expect(path, '/api/moment/userList');
      if (callCount == 1) {
        expect(data.containsKey('beforeMomentId'), isFalse);
        return {
          'code': 100,
          'data': {
            'items': [_momentJson(id: 2, content: '第二条')],
            'hasMore': true,
          },
        };
      }
      expect(data['beforeMomentId'], '2');
      return {
        'code': 100,
        'data': {
          'items': [_momentJson(id: 1, content: '第一条')],
          'hasMore': false,
        },
      };
    });
    final repository = ServerMomentsRepository(
      apiClient: api,
      cache: InMemoryMomentsStorage(),
    );

    final moments = await repository.fetchUserMoments('me');

    expect(callCount, 2);
    expect(moments.map((moment) => moment.id), ['2', '1']);
  });

  test('uses cached own moments when loading from server fails', () async {
    final cache = _ReadOnlyMomentsStorage();
    await cache.save([Moment.fromJson(_momentJson(id: 8, content: '离线动态'))]);
    final repository = ServerMomentsRepository(
      apiClient: _FakeMomentsApi((_, _) => throw Exception('offline')),
      cache: cache,
    );

    final moments = await repository.fetchOwnMoments('me');

    expect(moments.single.content, '离线动态');
  });

  test('exposes cached moments before a network refresh', () async {
    final cache = _ReadOnlyMomentsStorage();
    await cache.save([Moment.fromJson(_momentJson(id: 9, content: '本地优先动态'))]);
    final repository = ServerMomentsRepository(
      apiClient: _FakeMomentsApi((_, _) => throw Exception('not called')),
      cache: cache,
    );

    final moments = await repository.loadCachedMoments('me');

    expect(moments.single.content, '本地优先动态');
  });

  test('refreshing one author keeps other authors cached', () async {
    final cache = _ReadOnlyMomentsStorage();
    final other = Moment.fromJson({
      ..._momentJson(id: 7, content: '其他账号动态'),
      'authorId': 'other',
    });
    await cache.save([other]);
    final repository = ServerMomentsRepository(
      apiClient: _FakeMomentsApi((_, _) async {
        return {
          'code': 100,
          'data': {
            'items': [_momentJson(id: 10, content: '当前账号动态')],
          },
        };
      }),
      cache: cache,
    );

    await repository.fetchOwnMoments('me');

    expect((await repository.loadCachedMoments('me')).single.id, '10');
    expect((await repository.loadCachedMoments('other')).single.id, '7');
  });

  test('deletes a moment from the server and local cache', () async {
    final cache = _ReadOnlyMomentsStorage();
    await cache.save([Moment.fromJson(_momentJson(id: 8, content: '待删除'))]);
    final repository = ServerMomentsRepository(
      apiClient: _FakeMomentsApi((path, data) async {
        expect(path, '/api/moment/delete');
        expect(data['momentId'], '8');
        return {
          'code': 100,
          'data': {'momentId': 8},
        };
      }),
      cache: cache,
    );

    await repository.deleteMoment(momentId: '8', userId: 'me');

    expect(await cache.load(), isEmpty);
  });
}

Map<String, dynamic> _momentJson({required int id, required String content}) {
  return {
    'id': id,
    'authorId': 'me',
    'authorName': '小明',
    'authorAvatarUrl': '',
    'content': content,
    'mediaPaths': <String>[],
    'createdAt': 1700000000000,
    'visibility': 0,
    'location': null,
    'likeCount': 0,
    'isLiked': false,
    'comments': <Map<String, dynamic>>[],
  };
}

class _FakeMomentsApi implements MomentsApiClient {
  _FakeMomentsApi(this._handler);

  final Future<Map<String, dynamic>> Function(
    String path,
    Map<String, dynamic> data,
  )
  _handler;

  @override
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) {
    return _handler(path, data);
  }
}

class _ReadOnlyMomentsStorage implements MomentsLocalStorage {
  _ReadOnlyMomentsStorage([Iterable<Moment> initial = const []])
    : _moments = List<Moment>.of(initial);

  List<Moment> _moments;

  @override
  Future<List<Moment>> load() async => List<Moment>.unmodifiable(_moments);

  @override
  Future<void> save(List<Moment> moments) async {
    _moments = List<Moment>.of(moments);
  }
}
