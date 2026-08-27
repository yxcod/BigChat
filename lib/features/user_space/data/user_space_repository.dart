import '../../../utils/gloabl.dart';
import '../../../utils/http.dart';
import '../domain/user_space.dart';

abstract class UserSpaceRepository {
  Future<UserSpaceData> fetchSpace(String targetUserName);

  Future<String> updateCover(String coverImageUrl);

  Future<SpaceGuestbookMessage> addMessage({
    required String targetUserName,
    required String content,
  });

  Future<void> deleteMessage(String messageId);
}

abstract class UserSpaceApiClient {
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data);
}

class HttpUserSpaceApiClient implements UserSpaceApiClient {
  HttpUserSpaceApiClient({HttpUtil? httpUtil})
    : _httpUtil = httpUtil ?? HttpUtil();

  final HttpUtil _httpUtil;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _httpUtil.post(path, data: data);
    if (response.data is! Map) {
      throw const UserSpaceApiException('服务器返回格式错误');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }
}

class UserSpaceApiException implements Exception {
  const UserSpaceApiException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => message;
}

class ServerUserSpaceRepository implements UserSpaceRepository {
  ServerUserSpaceRepository({
    UserSpaceApiClient? apiClient,
    GlobalUtil? globalUtil,
  }) : _apiClient = apiClient ?? HttpUserSpaceApiClient(),
       _globalUtil = globalUtil ?? GlobalUtil();

  final UserSpaceApiClient _apiClient;
  final GlobalUtil _globalUtil;

  @override
  Future<UserSpaceData> fetchSpace(String targetUserName) async {
    final data = _requireData(
      await _apiClient.post('/api/space/detail', {
        'targetUserName': targetUserName,
        'messageLimit': 50,
      }),
    );
    final rawMessages = data['messages'];
    return UserSpaceData(
      ownerUserName: data['ownerUserName']?.toString() ?? targetUserName,
      isOwner: data['isOwner'] == true,
      coverImageUrl: data['coverImageUrl']?.toString() ?? '',
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map>()
                .map((item) => _parseMessage(Map<String, dynamic>.from(item)))
                .toList(growable: false)
          : const [],
    );
  }

  @override
  Future<String> updateCover(String coverImageUrl) async {
    final data = _requireData(
      await _apiClient.post('/api/space/updateCover', {
        'coverImageUrl': coverImageUrl,
      }),
    );
    return data['coverImageUrl']?.toString() ?? '';
  }

  @override
  Future<SpaceGuestbookMessage> addMessage({
    required String targetUserName,
    required String content,
  }) async {
    final data = _requireData(
      await _apiClient.post('/api/space/message/add', {
        'targetUserName': targetUserName,
        'content': content.trim(),
      }),
    );
    return _parseMessage(data);
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    _requireData(
      await _apiClient.post('/api/space/message/delete', {
        'messageId': messageId,
      }),
    );
  }

  Map<String, dynamic> _requireData(Map<String, dynamic> envelope) {
    final code = _asInt(envelope['code']);
    if (code != 100) {
      throw UserSpaceApiException(
        envelope['message']?.toString() ?? '空间请求失败',
        code: code,
      );
    }
    final data = envelope['data'];
    if (data is! Map) throw const UserSpaceApiException('空间数据格式错误');
    return Map<String, dynamic>.from(data);
  }

  SpaceGuestbookMessage _parseMessage(Map<String, dynamic> json) {
    final author = json['authorUserName']?.toString() ?? '';
    var avatar = json['authorAvatar']?.toString() ?? '';
    if (avatar.isNotEmpty &&
        !avatar.startsWith('http://') &&
        !avatar.startsWith('https://')) {
      try {
        avatar = _globalUtil.getImageURL(author, avatar);
      } catch (_) {
        avatar = '';
      }
    }
    return SpaceGuestbookMessage(
      id: json['messageId']?.toString() ?? '',
      ownerUserName: json['ownerUserName']?.toString() ?? '',
      authorUserName: author,
      authorNickName:
          json['authorNickName']?.toString().trim().isNotEmpty == true
          ? json['authorNickName'].toString().trim()
          : author,
      authorAvatarUrl: avatar,
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        _asInt(json['createdAt']) ?? 0,
      ),
    );
  }

  int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class InMemoryUserSpaceRepository implements UserSpaceRepository {
  InMemoryUserSpaceRepository({
    this.currentUserName = 'me',
    UserSpaceData? initialData,
  }) : _data = initialData;

  final String currentUserName;
  UserSpaceData? _data;

  @override
  Future<UserSpaceData> fetchSpace(String targetUserName) async {
    return _data ??= UserSpaceData(
      ownerUserName: targetUserName,
      isOwner: targetUserName == currentUserName,
    );
  }

  @override
  Future<String> updateCover(String coverImageUrl) async {
    final data = _data;
    if (data == null || !data.isOwner) throw StateError('无权修改封面');
    _data = data.copyWith(coverImageUrl: coverImageUrl);
    return coverImageUrl;
  }

  @override
  Future<SpaceGuestbookMessage> addMessage({
    required String targetUserName,
    required String content,
  }) async {
    final data = await fetchSpace(targetUserName);
    final message = SpaceGuestbookMessage(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      ownerUserName: targetUserName,
      authorUserName: currentUserName,
      authorNickName: currentUserName,
      authorAvatarUrl: '',
      content: content.trim(),
      createdAt: DateTime.now(),
    );
    _data = data.copyWith(messages: [message, ...data.messages]);
    return message;
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    final data = _data;
    if (data == null) return;
    _data = data.copyWith(
      messages: data.messages
          .where((message) => message.id != messageId)
          .toList(growable: false),
    );
  }
}
