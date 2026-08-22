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
      cache: InMemoryMomentsStorage(),
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
      cache: InMemoryMomentsStorage(),
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

  test('uses cached own moments when loading from server fails', () async {
    final cache = InMemoryMomentsStorage();
    await cache.save([Moment.fromJson(_momentJson(id: 8, content: '离线动态'))]);
    final repository = ServerMomentsRepository(
      apiClient: _FakeMomentsApi((_, _) => throw Exception('offline')),
      cache: cache,
    );

    final moments = await repository.fetchOwnMoments('me');

    expect(moments.single.content, '离线动态');
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
