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
}
