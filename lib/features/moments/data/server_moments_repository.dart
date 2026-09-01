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
      return _replaceAuthorCache(userId, moments);
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
      return _replaceAuthorCache(userId, moments);
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
    final clientRequestId =
        '${draft.authorId}-${DateTime.now().microsecondsSinceEpoch}';
    final request = <String, dynamic>{
      'content': draft.content.trim(),
      'mediaUrls': draft.mediaPaths.map((url) {
        final thumbnailUrl = draft.mediaThumbnailUrls[url];
        return thumbnailUrl == null || thumbnailUrl.isEmpty
            ? url
            : {'url': url, 'thumbnailUrl': thumbnailUrl};
      }).toList(),
      'visibility': draft.visibility.index,
      'location': draft.location,
      'clientRequestId': clientRequestId,
    };
    late Map<String, dynamic> data;
    try {
      final envelope = await _apiClient.post('/api/moment/publish', request);
      data = _requireMapData(envelope);
    } catch (_) {
      if (draft.mediaThumbnailUrls.isEmpty) rethrow;
      final fallbackRequest = Map<String, dynamic>.of(request)
        ..['mediaUrls'] = draft.mediaPaths;
      final envelope = await _apiClient.post(
        '/api/moment/publish',
        fallbackRequest,
      );
      data = _requireMapData(envelope);
    }
    final moment = _parseMoment(data).copyWith(
      mediaThumbnails: draft.mediaThumbnailUrls,
      localMediaPaths: draft.localMediaPaths,
      localThumbnailPaths: draft.localThumbnailPaths,
    );
    return _upsertCache(moment);
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
    return _upsertCache(moment);
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
    return _upsertCache(moment);
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

  Future<Moment> _upsertCache(Moment updated) async {
    final moments = List<Moment>.of(await _cache.load());
    final index = moments.indexWhere((moment) => moment.id == updated.id);
    if (index == -1) {
      moments.insert(0, updated);
    } else {
      updated = _mergeLocalMedia(updated, moments[index]);
      moments[index] = updated;
    }
    await _cache.save(moments);
    return updated;
  }

  Future<List<Moment>> _replaceAuthorCache(
    String authorId,
    Iterable<Moment> latest,
  ) async {
    final moments = List<Moment>.of(await _cache.load());
    final cachedById = {for (final item in moments) item.id: item};
    final merged = latest
        .map(
          (item) => cachedById[item.id] == null
              ? item
              : _mergeLocalMedia(item, cachedById[item.id]!),
        )
        .toList(growable: false);
    moments.removeWhere((moment) => moment.authorId == authorId);
    moments.addAll(merged);
    await _cache.save(moments);
    return List<Moment>.unmodifiable(merged);
  }

  Moment _mergeLocalMedia(Moment server, Moment cached) {
    final activeUrls = server.mediaPaths.toSet();
    return server.copyWith(
      mediaThumbnails: {...cached.mediaThumbnails, ...server.mediaThumbnails},
      localMediaPaths: {
        for (final entry in cached.localMediaPaths.entries)
          if (activeUrls.contains(entry.key)) entry.key: entry.value,
      },
      localThumbnailPaths: {
        for (final entry in cached.localThumbnailPaths.entries)
          if (activeUrls.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  int? _readInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
