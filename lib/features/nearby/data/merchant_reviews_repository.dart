import 'dart:convert';

import '../../../utils/storageUtil.dart';
import '../../../utils/http.dart';
import '../domain/merchant_review.dart';
import '../domain/nearby_merchant.dart';

typedef MerchantReviewsReader = String? Function(String key);
typedef MerchantReviewsWriter = Future<void> Function(String key, String value);

abstract class MerchantReviewsApiClient {
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data);
}

class HttpMerchantReviewsApiClient implements MerchantReviewsApiClient {
  HttpMerchantReviewsApiClient({HttpUtil? httpUtil})
    : _httpUtil = httpUtil ?? HttpUtil();

  final HttpUtil _httpUtil;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    final response = await _httpUtil.post(path, data: data);
    final body = response.data;
    if (body is! Map) throw const MerchantReviewsApiException('服务器返回格式错误');
    return Map<String, dynamic>.from(body);
  }
}

class MerchantReviewsApiException implements Exception {
  const MerchantReviewsApiException(this.message, {this.code});

  final String message;
  final int? code;

  @override
  String toString() => message;
}

class MerchantReviewsRepository {
  MerchantReviewsRepository({
    String? ownerId,
    MerchantReviewsReader? read,
    MerchantReviewsWriter? write,
    MerchantReviewsApiClient? apiClient,
  }) : _ownerId = (ownerId ?? StorageUtil.getUserId() ?? 'device').trim(),
       _read = read,
       _write = write,
       _apiClient =
           apiClient ??
           (read == null && write == null
               ? HttpMerchantReviewsApiClient()
               : null);

  final String _ownerId;
  final MerchantReviewsReader? _read;
  final MerchantReviewsWriter? _write;
  final MerchantReviewsApiClient? _apiClient;

  String get _storageKey =>
      'nearby_merchant_reviews_${Uri.encodeComponent(_ownerId)}';

  Future<List<MerchantReview>> load() async {
    final cached = await _loadCache();
    if (_apiClient == null) return cached;
    try {
      var remote = await _loadRemote();
      final pending = cached.where((item) => item.entryId.isEmpty).toList();
      if (pending.isNotEmpty) {
        for (final review in pending) {
          await _migrateLocalReview(review);
        }
        remote = await _loadRemote();
      }
      await _save(remote);
      return remote;
    } catch (_) {
      return cached;
    }
  }

  Future<List<MerchantReview>> _loadCache() async {
    if (_read == null) await StorageUtil.init();
    final raw = _read?.call(_storageKey) ?? StorageUtil.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) => MerchantReview.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.merchant.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<MerchantReview> addMerchant(NearbyMerchant merchant) async {
    final reviews = await load();
    final existingIndex = reviews.indexWhere(
      (item) => item.merchant.id == merchant.id,
    );
    if (existingIndex >= 0) return reviews[existingIndex];

    if (_apiClient != null) {
      try {
        final review = await _addRemoteMerchant(merchant);
        await _upsertCache(reviews, review);
        return review;
      } catch (_) {
        // Keep an offline entry. It is migrated automatically on the next load.
      }
    }

    final review = MerchantReview(
      merchant: merchant,
      addedAt: DateTime.now(),
      ownerUserName: _ownerId,
    );
    await _save([...reviews, review]);
    return review;
  }

  Future<MerchantReview> setReaction(
    String merchantId,
    MerchantReviewReaction nextReaction,
  ) async {
    final reviews = await load();
    final index = reviews.indexWhere((item) => item.merchant.id == merchantId);
    if (index < 0) throw StateError('点评商家不存在');

    final current = reviews[index];
    final effectiveReaction = current.reaction == nextReaction
        ? MerchantReviewReaction.none
        : nextReaction;
    if (_apiClient != null && current.entryId.isNotEmpty) {
      final updated = _parseReview(
        _requireData(
          await _apiClient.post('/api/merchantReview/reaction', {
            'entryId': current.entryId,
            'reaction': effectiveReaction.name,
          }),
        ),
      );
      await _upsertCache(reviews, updated);
      return updated;
    }

    var likes = current.likes;
    var dislikes = current.dislikes;
    if (current.reaction == MerchantReviewReaction.like) {
      likes = (likes - 1).clamp(0, 1 << 31);
    } else if (current.reaction == MerchantReviewReaction.dislike) {
      dislikes = (dislikes - 1).clamp(0, 1 << 31);
    }

    if (effectiveReaction == MerchantReviewReaction.like) {
      likes += 1;
    } else if (effectiveReaction == MerchantReviewReaction.dislike) {
      dislikes += 1;
    }

    final updated = current.copyWith(
      likes: likes,
      dislikes: dislikes,
      reaction: effectiveReaction,
    );
    final next = [...reviews]..[index] = updated;
    await _save(next);
    return updated;
  }

  Future<MerchantReview> addComment(String merchantId, String content) async {
    final normalized = content.trim();
    if (normalized.isEmpty) throw ArgumentError('评论内容不能为空');

    final reviews = await load();
    final index = reviews.indexWhere((item) => item.merchant.id == merchantId);
    if (index < 0) throw StateError('点评商家不存在');

    final current = reviews[index];
    if (_apiClient != null && current.entryId.isNotEmpty) {
      final updated = _parseReview(
        _requireData(
          await _apiClient.post('/api/merchantReview/comment', {
            'entryId': current.entryId,
            'content': normalized,
          }),
        ),
      );
      await _upsertCache(reviews, updated);
      return updated;
    }

    final now = DateTime.now();
    final comment = MerchantReviewComment(
      id: '${now.microsecondsSinceEpoch}',
      userId: _ownerId,
      displayName: '我',
      content: normalized,
      createdAt: now,
    );
    final updated = current.copyWith(comments: [...current.comments, comment]);
    final next = [...reviews]..[index] = updated;
    await _save(next);
    return updated;
  }

  Future<void> _save(List<MerchantReview> reviews) async {
    final value = jsonEncode(reviews.map((item) => item.toJson()).toList());
    if (_write != null) {
      await _write(_storageKey, value);
      return;
    }
    await StorageUtil.setString(_storageKey, value);
  }

  Future<List<MerchantReview>> _loadRemote() async {
    final data = _requireData(
      await _apiClient!.post('/api/merchantReview/list', {
        'targetUserName': _ownerId,
        'limit': 200,
      }),
    );
    final items = data['items'];
    if (items is! List) throw const MerchantReviewsApiException('点评列表格式错误');
    return items
        .whereType<Map>()
        .map((item) => _parseReview(Map<String, dynamic>.from(item)))
        .where((item) => item.merchant.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<MerchantReview> _addRemoteMerchant(NearbyMerchant merchant) async {
    final data = _requireData(
      await _apiClient!.post('/api/merchantReview/add', {
        'merchant': merchantReviewMerchantToJson(merchant),
      }),
    );
    return _parseReview(data);
  }

  Future<void> _migrateLocalReview(MerchantReview local) async {
    var remote = await _addRemoteMerchant(local.merchant);
    if (local.reaction != MerchantReviewReaction.none &&
        remote.reaction != local.reaction) {
      remote = _parseReview(
        _requireData(
          await _apiClient!.post('/api/merchantReview/reaction', {
            'entryId': remote.entryId,
            'reaction': local.reaction.name,
          }),
        ),
      );
    }
    for (final comment in local.comments) {
      final alreadyMigrated = remote.comments.any(
        (item) =>
            item.content == comment.content &&
            (item.userId.isEmpty || item.userId == _ownerId),
      );
      if (alreadyMigrated) continue;
      remote = _parseReview(
        _requireData(
          await _apiClient!.post('/api/merchantReview/comment', {
            'entryId': remote.entryId,
            'content': comment.content,
          }),
        ),
      );
    }
  }

  Map<String, dynamic> _requireData(Map<String, dynamic> envelope) {
    final code = _readInt(envelope['code']);
    if (code != 100) {
      throw MerchantReviewsApiException(
        envelope['message']?.toString() ?? '点评请求失败',
        code: code,
      );
    }
    final data = envelope['data'];
    if (data is! Map) throw const MerchantReviewsApiException('点评数据格式错误');
    return Map<String, dynamic>.from(data);
  }

  MerchantReview _parseReview(Map<String, dynamic> json) {
    return MerchantReview.fromJson(json);
  }

  Future<void> _upsertCache(
    List<MerchantReview> reviews,
    MerchantReview updated,
  ) async {
    final next = [...reviews];
    final index = next.indexWhere(
      (item) =>
          (updated.entryId.isNotEmpty && item.entryId == updated.entryId) ||
          item.merchant.id == updated.merchant.id,
    );
    if (index < 0) {
      next.add(updated);
    } else {
      next[index] = updated;
    }
    await _save(next);
  }

  int? _readInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

Map<String, dynamic> merchantReviewMerchantToJson(NearbyMerchant merchant) => {
  'id': merchant.id,
  'name': merchant.name,
  'address': merchant.address,
  'category': merchant.category,
  'distanceMeters': merchant.distanceMeters,
  'rating': merchant.rating,
  'imageUrl': merchant.imageUrl,
  'imageUrls': merchant.imageUrls,
  'phone': merchant.phone,
  'openingHours': merchant.openingHours,
  'price': merchant.price,
  'detailUrl': merchant.detailUrl,
  'imageCount': merchant.imageCount,
  'latitude': merchant.latitude,
  'longitude': merchant.longitude,
};
