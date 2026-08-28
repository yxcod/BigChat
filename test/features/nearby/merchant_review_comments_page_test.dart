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
          avatarName: 'head.jpg',
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

    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const ValueKey('merchant_comment_avatar_comment-1')),
    );
    expect(avatar.backgroundImage, isNotNull);

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

  testWidgets('send action stays visible when comment has text', (
    tester,
  ) async {
    String? storedValue;
    final repository = MerchantReviewsRepository(
      ownerId: 'owner',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    const merchant = NearbyMerchant(id: 'food-2', name: '北城小馆');
    await repository.addMerchant(merchant);
    final review = (await repository.load()).single;

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantReviewCommentsPage(
          review: review,
          repository: repository,
          currentUserId: 'owner',
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('merchant_review_comment_field')),
      '值得再来',
    );
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('merchant_review_send_comment')),
        matching: find.byIcon(Icons.send_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('author can delete own comment', (tester) async {
    String? storedValue;
    final repository = MerchantReviewsRepository(
      ownerId: 'owner',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    const merchant = NearbyMerchant(id: 'food-3', name: '西城小馆');
    await repository.addMerchant(merchant);
    final commented = await repository.addComment('food-3', '准备删除');
    final commentId = commented.comments.single.id;

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantReviewCommentsPage(
          review: commented,
          repository: repository,
          currentUserId: 'owner',
        ),
      ),
    );
    await tester.tap(
      find.byKey(ValueKey('remove_merchant_comment_$commentId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm_remove_merchant_comment')),
    );
    await tester.pumpAndSettle();

    expect(find.text('准备删除'), findsNothing);
    expect((await repository.load()).single.comments, isEmpty);
  });
}
