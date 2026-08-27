import 'package:flutter_base/features/nearby/data/merchant_reviews_repository.dart';
import 'package:flutter_base/features/nearby/domain/merchant_review.dart';
import 'package:flutter_base/features/nearby/domain/nearby_merchant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'persists merchant reaction and comments without adding duplicates',
    () async {
      String? storedValue;
      final repository = MerchantReviewsRepository(
        ownerId: 'tester',
        read: (_) => storedValue,
        write: (_, value) async => storedValue = value,
      );
      const merchant = NearbyMerchant(id: 'food-1', name: '南城小馆');

      await repository.addMerchant(merchant);
      await repository.addMerchant(merchant);
      await repository.setReaction('food-1', MerchantReviewReaction.like);
      await repository.addComment('food-1', '味道不错');

      final reviews = await repository.load();
      expect(reviews, hasLength(1));
      expect(reviews.single.likes, 1);
      expect(reviews.single.dislikes, 0);
      expect(reviews.single.reaction, MerchantReviewReaction.like);
      expect(reviews.single.comments.single.content, '味道不错');
    },
  );

  test('sorts by likes, fewer dislikes, then more comments', () {
    final now = DateTime(2026, 8, 27);
    MerchantReview review(
      String id, {
      required int likes,
      required int dislikes,
      int comments = 0,
    }) {
      return MerchantReview(
        merchant: NearbyMerchant(id: id, name: id),
        addedAt: now,
        likes: likes,
        dislikes: dislikes,
        comments: List.generate(
          comments,
          (index) => MerchantReviewComment(
            id: '$id-$index',
            content: '评论',
            createdAt: now,
          ),
        ),
      );
    }

    final sorted = sortMerchantReviews([
      review('low-likes', likes: 3, dislikes: 0, comments: 9),
      review('more-dislikes', likes: 8, dislikes: 4, comments: 9),
      review('more-comments', likes: 8, dislikes: 1, comments: 5),
      review('fewer-comments', likes: 8, dislikes: 1, comments: 2),
    ]);

    expect(sorted.map((item) => item.merchant.id), [
      'more-comments',
      'fewer-comments',
      'more-dislikes',
      'low-likes',
    ]);
  });

  test('removes a collected merchant from local storage', () async {
    String? storedValue;
    final repository = MerchantReviewsRepository(
      ownerId: 'tester',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    await repository.addMerchant(
      const NearbyMerchant(id: 'remove-local', name: '待移除商家'),
    );

    await repository.removeMerchant('remove-local');

    expect(await repository.load(), isEmpty);
  });

  test('persists merchant, reaction and comment through server API', () async {
    String? storedValue;
    final api = _FakeMerchantReviewsApiClient();
    final repository = MerchantReviewsRepository(
      ownerId: 'tester',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
      apiClient: api,
    );

    await repository.addMerchant(
      const NearbyMerchant(id: 'food-2', name: '北城小馆'),
    );
    await repository.setReaction('food-2', MerchantReviewReaction.like);
    await repository.addComment('food-2', '服务很好');
    await repository.removeMerchant('food-2');

    expect(
      api.paths,
      containsAll(<String>[
        '/api/merchantReview/add',
        '/api/merchantReview/reaction',
        '/api/merchantReview/comment',
        '/api/merchantReview/remove',
      ]),
    );
    final reviews = await repository.load();
    expect(reviews, isEmpty);
  });

  test('migrates an existing local review to server once', () async {
    String? storedValue;
    final local = MerchantReviewsRepository(
      ownerId: 'tester',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    await local.addMerchant(const NearbyMerchant(id: 'legacy', name: '老店'));
    await local.addComment('legacy', '历史评论');

    final api = _FakeMerchantReviewsApiClient();
    final server = MerchantReviewsRepository(
      ownerId: 'tester',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
      apiClient: api,
    );
    final first = await server.load();
    final second = await server.load();

    expect(first.single.entryId, '42');
    expect(second.single.comments, hasLength(1));
    expect(
      api.paths.where((path) => path == '/api/merchantReview/comment'),
      hasLength(1),
    );
  });
}

class _FakeMerchantReviewsApiClient implements MerchantReviewsApiClient {
  final List<String> paths = [];
  Map<String, dynamic>? _review;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    paths.add(path);
    switch (path) {
      case '/api/merchantReview/list':
        return _success({
          'items': _review == null ? [] : [_review],
        });
      case '/api/merchantReview/add':
        final merchant = Map<String, dynamic>.from(data['merchant'] as Map);
        _review ??= {
          'entryId': 42,
          'ownerUserName': 'tester',
          'merchant': merchant,
          'addedAt': DateTime(2026, 8, 27).millisecondsSinceEpoch,
          'likes': 0,
          'dislikes': 0,
          'reaction': 'none',
          'comments': <Map<String, dynamic>>[],
        };
        return _success(_review!);
      case '/api/merchantReview/reaction':
        final oldReaction = _review!['reaction'];
        if (oldReaction == 'like') _review!['likes'] = 0;
        if (oldReaction == 'dislike') _review!['dislikes'] = 0;
        final reaction = data['reaction'];
        _review!['reaction'] = reaction;
        if (reaction == 'like') _review!['likes'] = 1;
        if (reaction == 'dislike') _review!['dislikes'] = 1;
        return _success(_review!);
      case '/api/merchantReview/comment':
        final comments = _review!['comments'] as List<Map<String, dynamic>>;
        comments.add({
          'id': comments.length + 1,
          'userId': 'tester',
          'displayName': '测试用户',
          'content': data['content'],
          'createdAt': DateTime(2026, 8, 27).millisecondsSinceEpoch,
        });
        return _success(_review!);
      case '/api/merchantReview/remove':
        _review = null;
        return _success({'entryId': data['entryId']});
      default:
        throw StateError('Unexpected path: $path');
    }
  }

  Map<String, dynamic> _success(Map<String, dynamic> data) => {
    'code': 100,
    'message': 'success',
    'data': data,
  };
}
