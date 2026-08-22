import '../../../utils/gloabl.dart';
import '../../../utils/http.dart';
import '../domain/moment.dart';
import 'moments_local_storage.dart';
import 'moments_repository.dart';

abstract class MomentsApiClient {
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data);
}

class HttpMomentsApiClient implements MomentsApiClient {
  HttpMomentsApiClient({HttpUtil? httpUtil})
    : _httpUtil = httpUtil ?? HttpUtil();

  final HttpUtil _httpUtil;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _httpUtil.post(path, data: data);
    final body = response.data;
    if (body is! Map) {
      throw const MomentsApiException('服务器返回格式错误');
    }
    return Map<String, dynamic>.from(body);
  }
}

class MomentsApiException implements Exception {
  const MomentsApiException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => message;
}

class ServerMomentsRepository implements MomentsRepository {
  ServerMomentsRepository({
    MomentsApiClient? apiClient,
    MomentsLocalStorage? cache,
    GlobalUtil? globalUtil,
  }) : _apiClient = apiClient ?? HttpMomentsApiClient(),
       _cache = cache ?? FileMomentsStorage(),
       _globalUtil = globalUtil ?? GlobalUtil();

  static final ServerMomentsRepository instance = ServerMomentsRepository();

  final MomentsApiClient _apiClient;
  final MomentsLocalStorage _cache;
  final GlobalUtil _globalUtil;

  @override
  Future<List<Moment>> fetchOwnMoments(String userId) async {
    try {
      final envelope = await _apiClient.post('/api/moment/ownList', {
        'limit': 50,
      });
      final data = _requireMapData(envelope);
      final rawItems = data['items'];
      if (rawItems is! List) {
        throw const MomentsApiException('动态列表格式错误');
      }
      final moments = rawItems
          .whereType<Map>()
          .map((item) => _parseMoment(Map<String, dynamic>.from(item)))
          .where((moment) => moment.authorId == userId)
          .toList(growable: false);
      await _cache.save(moments);
      return moments;
    } catch (_) {
      final cached = (await _cache.load())
          .where((moment) => moment.authorId == userId)
          .toList(growable: false);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  @override
  Future<Moment> publish(MomentDraft draft) async {
    final envelope = await _apiClient.post('/api/moment/publish', {
      'content': draft.content.trim(),
      'mediaUrls': draft.mediaPaths,
      'visibility': draft.visibility.index,
      'location': draft.location,
      'clientRequestId':
          '${draft.authorId}-${DateTime.now().microsecondsSinceEpoch}',
    });
    final moment = _parseMoment(_requireMapData(envelope));
    await _upsertCache(moment);
    return moment;
  }

  @override
  Future<Moment> toggleLike({
    required String momentId,
    required String userId,
  }) async {
    final envelope = await _apiClient.post('/api/moment/toggleLike', {
      'momentId': momentId,
    });
    final moment = _parseMoment(_requireMapData(envelope));
    await _upsertCache(moment);
    return moment;
  }

  @override
  Future<Moment> addComment({
    required String momentId,
    required String userId,
    required String displayName,
    required String content,
  }) async {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw ArgumentError.value(content, 'content', '评论不能为空');
    }
    final envelope = await _apiClient.post('/api/moment/comment', {
      'momentId': momentId,
      'content': normalizedContent,
    });
    final moment = _parseMoment(_requireMapData(envelope));
    await _upsertCache(moment);
    return moment;
  }

  Map<String, dynamic> _requireMapData(Map<String, dynamic> envelope) {
    final code = _readInt(envelope['code']);
    if (code != 100) {
      throw MomentsApiException(
        envelope['message']?.toString() ?? '动态请求失败',
        code: code,
      );
    }
    final data = envelope['data'];
    if (data is! Map) {
      throw const MomentsApiException('动态数据格式错误');
    }
    return Map<String, dynamic>.from(data);
  }

  Moment _parseMoment(Map<String, dynamic> json) {
    final authorId = json['authorId']?.toString() ?? '';
    final avatar = json['authorAvatarUrl']?.toString() ?? '';
    if (authorId.isNotEmpty &&
        avatar.isNotEmpty &&
        !avatar.startsWith('http://') &&
        !avatar.startsWith('https://')) {
      try {
        json['authorAvatarUrl'] = _globalUtil.getImageURL(authorId, avatar);
      } catch (_) {
        json['authorAvatarUrl'] = '';
      }
    }
    return Moment.fromJson(json);
  }

  Future<void> _upsertCache(Moment updated) async {
    final moments = await _cache.load();
    final index = moments.indexWhere((moment) => moment.id == updated.id);
    if (index == -1) {
      moments.insert(0, updated);
    } else {
      moments[index] = updated;
    }
    await _cache.save(moments);
  }

  int? _readInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
