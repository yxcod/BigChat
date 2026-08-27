import 'dart:convert';

import '../../../utils/storageUtil.dart';
import '../domain/merchant_review.dart';
import '../domain/nearby_merchant.dart';

typedef MerchantReviewsReader = String? Function(String key);
typedef MerchantReviewsWriter = Future<void> Function(String key, String value);

class MerchantReviewsRepository {
  MerchantReviewsRepository({
    String? ownerId,
    MerchantReviewsReader? read,
    MerchantReviewsWriter? write,
  }) : _ownerId = (ownerId ?? StorageUtil.getUserId() ?? 'device').trim(),
       _read = read,
       _write = write;

  final String _ownerId;
  final MerchantReviewsReader? _read;
  final MerchantReviewsWriter? _write;

  String get _storageKey =>
      'nearby_merchant_reviews_${Uri.encodeComponent(_ownerId)}';

  Future<List<MerchantReview>> load() async {
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

    final review = MerchantReview(merchant: merchant, addedAt: DateTime.now());
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
    var likes = current.likes;
    var dislikes = current.dislikes;
    if (current.reaction == MerchantReviewReaction.like) {
      likes = (likes - 1).clamp(0, 1 << 31);
    } else if (current.reaction == MerchantReviewReaction.dislike) {
      dislikes = (dislikes - 1).clamp(0, 1 << 31);
    }

    final effectiveReaction = current.reaction == nextReaction
        ? MerchantReviewReaction.none
        : nextReaction;
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
    final now = DateTime.now();
    final comment = MerchantReviewComment(
      id: '${now.microsecondsSinceEpoch}',
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
}
