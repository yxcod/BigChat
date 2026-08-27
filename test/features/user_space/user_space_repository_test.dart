import 'package:flutter_base/features/user_space/data/user_space_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server repository maps space details and guestbook messages', () async {
    final api = _FakeUserSpaceApiClient({
      '/api/space/detail': {
        'code': 100,
        'data': {
          'ownerUserName': 'owner',
          'isOwner': false,
          'coverImageUrl': 'https://example.com/cover.jpg',
          'messages': [
            {
              'messageId': 'm1',
              'ownerUserName': 'owner',
              'authorUserName': 'visitor',
              'authorNickName': '叶翔',
              'authorAvatar': 'https://example.com/avatar.jpg',
              'content': '最近怎么样',
              'createdAt': 1777248000000,
            },
          ],
        },
      },
    });

    final space = await ServerUserSpaceRepository(
      apiClient: api,
    ).fetchSpace('owner');

    expect(space.ownerUserName, 'owner');
    expect(space.isOwner, isFalse);
    expect(space.coverImageUrl, 'https://example.com/cover.jpg');
    expect(space.messages.single.authorNickName, '叶翔');
    expect(space.messages.single.content, '最近怎么样');
    expect(api.requests.single.data['messageLimit'], 50);
  });

  test('server repository sends add, cover and delete requests', () async {
    final api = _FakeUserSpaceApiClient({
      '/api/space/updateCover': {
        'code': 100,
        'data': {'coverImageUrl': 'https://example.com/new.jpg'},
      },
      '/api/space/message/add': {
        'code': 100,
        'data': {
          'messageId': 'm2',
          'ownerUserName': 'owner',
          'authorUserName': 'visitor',
          'authorNickName': '访客',
          'authorAvatar': '',
          'content': '你好',
          'createdAt': 1777248000000,
        },
      },
      '/api/space/message/delete': {'code': 100, 'data': <String, dynamic>{}},
    });
    final repository = ServerUserSpaceRepository(apiClient: api);

    expect(
      await repository.updateCover('https://example.com/new.jpg'),
      'https://example.com/new.jpg',
    );
    expect(
      (await repository.addMessage(
        targetUserName: 'owner',
        content: '  你好  ',
      )).content,
      '你好',
    );
    await repository.deleteMessage('m2');

    expect(api.requests[1].data['content'], '你好');
    expect(api.requests[2].data['messageId'], 'm2');
  });
}

class _Request {
  const _Request(this.path, this.data);

  final String path;
  final Map<String, dynamic> data;
}

class _FakeUserSpaceApiClient implements UserSpaceApiClient {
  _FakeUserSpaceApiClient(this.responses);

  final Map<String, Map<String, dynamic>> responses;
  final List<_Request> requests = [];

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    requests.add(_Request(path, data));
    return responses[path]!;
  }
}
