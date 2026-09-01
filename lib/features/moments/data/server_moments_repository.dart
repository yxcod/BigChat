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

class ServerMomentsRepository
    implements MomentsRepository, CachedMomentsReader {
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
      final moments = _parseMomentList(envelope, authorId: userId);
      await _replaceAuthorCache(userId, moments);
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
  Future<List<Moment>> fetchUserMoments(String userId, {int? maxItems}) async {
    try {
      final moments = <Moment>[];
      String? beforeMomentId;
      while (maxItems == null || moments.length < maxItems) {
        final remaining = maxItems == null ? 50 : maxItems - moments.length;
        final request = <String, dynamic>{
          'targetUserName': userId,
          'limit': remaining.clamp(1, 50),
          if (beforeMomentId != null) 'beforeMomentId': beforeMomentId,
        };
        final envelope = await _apiClient.post('/api/moment/userList', request);
        final data = _requireMapData(envelope);
        final page = _parseMomentItems(data, authorId: userId);
        moments.addAll(page);
        final hasMore = data['hasMore'] == true;
        if (!hasMore || page.isEmpty) break;
        final nextCursor = page.last.id;
        if (nextCursor == beforeMomentId) break;
        beforeMomentId = nextCursor;
      }
      await _replaceAuthorCache(userId, moments);
      return List<Moment>.unmodifiable(moments);
    } catch (_) {
      final cached = await loadCachedMoments(userId, maxItems: maxItems);
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  @override
  Future<List<Moment>> loadCachedMoments(String userId, {int? maxItems}) async {
    final cached =
        (await _cache.load())
            .where((moment) => moment.authorId == userId)
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final result = maxItems == null ? cached : cached.take(maxItems).toList();
    return List<Moment>.unmodifiable(result);
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

  @override
  Future<void> deleteMoment({
    required String momentId,
    required String userId,
  }) async {
    final envelope = await _apiClient.post('/api/moment/delete', {
      'momentId': momentId,
    });
    final code = _readInt(envelope['code']);
    if (code != 100) {
      throw MomentsApiException(
        envelope['message']?.toString() ?? '删除动态失败',
        code: code,
      );
    }
    final moments = List<Moment>.of(await _cache.load());
    moments.removeWhere(
      (moment) => moment.id == momentId && moment.authorId == userId,
    );
    await _cache.save(moments);
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

  List<Moment> _parseMomentList(
    Map<String, dynamic> envelope, {
    required String authorId,
  }) {
    final data = _requireMapData(envelope);
    return _parseMomentItems(data, authorId: authorId);
  }

  List<Moment> _parseMomentItems(
    Map<String, dynamic> data, {
    required String authorId,
  }) {
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const MomentsApiException('动态列表格式错误');
    }
    return rawItems
        .whereType<Map>()
        .map((item) => _parseMoment(Map<String, dynamic>.from(item)))
        .where((moment) => moment.authorId == authorId)
        .toList(growable: false);
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
    final moments = List<Moment>.of(await _cache.load());
    final index = moments.indexWhere((moment) => moment.id == updated.id);
    if (index == -1) {
      moments.insert(0, updated);
    } else {
      moments[index] = updated;
    }
    await _cache.save(moments);
  }

  Future<void> _replaceAuthorCache(
    String authorId,
    Iterable<Moment> latest,
  ) async {
    final moments = List<Moment>.of(await _cache.load());
    moments.removeWhere((moment) => moment.authorId == authorId);
    moments.addAll(latest);
    await _cache.save(moments);
  }

  int? _readInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
