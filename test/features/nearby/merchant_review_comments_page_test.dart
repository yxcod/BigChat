import 'package:flutter/material.dart';
import 'package:flutter_base/features/nearby/data/merchant_reviews_repository.dart';
import 'package:flutter_base/features/nearby/domain/merchant_review.dart';
import 'package:flutter_base/features/nearby/domain/nearby_merchant.dart';
import 'package:flutter_base/features/nearby/presentation/merchant_review_comments_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('comment image opens fullscreen viewer and closes on tap', (
    tester,
  ) async {
    String? storedValue;
    final repository = MerchantReviewsRepository(
      ownerId: 'owner',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    final review = MerchantReview(
      merchant: const NearbyMerchant(id: 'food-1', name: '南城小馆'),
      addedAt: DateTime(2026, 8, 28),
      comments: [
        MerchantReviewComment(
          id: 'comment-1',
          userId: 'visitor',
          displayName: '访客',
          content: '很好吃',
          imageName: 'review.jpg',
          createdAt: DateTime(2026, 8, 28),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantReviewCommentsPage(
          review: review,
          repository: repository,
          imageUrlBuilder: (_, _) => 'https://example.invalid/review.jpg',
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('merchant_comment_image_comment-1')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('merchant_comment_image_comment-1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('fullscreen_image_viewer')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('fullscreen_image_viewer')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('fullscreen_image_viewer')), findsNothing);
  });
}
