import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_base/features/nearby/data/merchant_reviews_repository.dart';
import 'package:flutter_base/features/nearby/domain/nearby_merchant.dart';
import 'package:flutter_base/features/nearby/presentation/merchant_reviews_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filters reviewed merchants by category', (tester) async {
    String? storedValue;
    final repository = MerchantReviewsRepository(
      ownerId: 'tester',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    await repository.addMerchant(
      const NearbyMerchant(id: 'food-1', name: '南城小馆', category: '美食;本帮菜'),
    );
    await repository.addMerchant(
      const NearbyMerchant(id: 'fun-1', name: '星河游乐城', category: '娱乐;室内游乐'),
    );

    await tester.pumpWidget(
      MaterialApp(home: MerchantReviewsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('南城小馆'), findsOneWidget);
    expect(find.text('星河游乐城'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('merchant_review_filter_玩乐')));
    await tester.pumpAndSettle();

    expect(find.text('南城小馆'), findsNothing);
    expect(find.text('星河游乐城'), findsOneWidget);
  });

  testWidgets('updates the like count from the review card', (tester) async {
    String? storedValue;
    final repository = MerchantReviewsRepository(
      ownerId: 'tester',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    await repository.addMerchant(
      const NearbyMerchant(id: 'coffee-1', name: '巷口咖啡'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantReviewsPage(
          repository: repository,
          merchantImageProviderBuilder: (_) => MemoryImage(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
              'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('赞 0'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('merchant_review_like_coffee-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('赞 1'), findsOneWidget);
  });

  testWidgets('owner can remove a collected merchant', (tester) async {
    String? storedValue;
    final repository = MerchantReviewsRepository(
      ownerId: 'tester',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    await repository.addMerchant(
      const NearbyMerchant(id: 'remove-1', name: '待移除商家'),
    );

    await tester.pumpWidget(
      MaterialApp(home: MerchantReviewsPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('merchant_review_menu_remove-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('移除收录'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm_remove_merchant_review')),
    );
    await tester.pumpAndSettle();

    expect(find.text('待移除商家'), findsNothing);
    expect(await repository.load(), isEmpty);
  });

  testWidgets('merchant images can be swiped and opened fullscreen', (
    tester,
  ) async {
    String? storedValue;
    final repository = MerchantReviewsRepository(
      ownerId: 'tester',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    await repository.addMerchant(
      const NearbyMerchant(id: 'gallery-1', name: '图片商家'),
    );
    await repository.setMerchantImages('gallery-1', [
      'gallery-1.jpg',
      'gallery-2.jpg',
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: MerchantReviewsPage(
          repository: repository,
          merchantImageProviderBuilder: (_) => MemoryImage(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
              'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('merchant_review_gallery_gallery-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('merchant_review_gallery_image_0')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('merchant_review_gallery_image_0')),
      const Offset(-400, 0),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('merchant_review_gallery_image_1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('merchant_review_gallery_image_1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });
}
