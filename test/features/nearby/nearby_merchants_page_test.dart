import 'package:flutter/material.dart';
import 'package:flutter_base/features/nearby/data/merchant_reviews_repository.dart';
import 'package:flutter_base/features/nearby/domain/nearby_merchant.dart';
import 'package:flutter_base/features/nearby/presentation/nearby_merchants_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows merchant image area, distance and address', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyMerchantsPage(
          loader: (_) async => const NearbyMerchantsResult(
            currentCity: '南京市',
            merchants: [
              NearbyMerchant(
                id: 'coffee-1',
                name: '蓝鲸咖啡',
                category: '美食;咖啡厅',
                address: '中山东路1号',
                distanceMeters: 180,
                rating: 4.8,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('附近'), findsOneWidget);
    expect(find.text('蓝鲸咖啡'), findsOneWidget);
    expect(find.text('180m'), findsOneWidget);
    expect(find.text('中山东路1号'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
  });

  testWidgets('search field sends the typed merchant query', (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyMerchantsPage(
          loader: (query) async {
            queries.add(query);
            return const NearbyMerchantsResult(
              currentCity: '南京市',
              merchants: [],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('nearby_merchant_search_field')),
      '火锅',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(queries, contains('火锅'));
  });

  testWidgets('right swipe adds a merchant and opens my reviews', (
    tester,
  ) async {
    String? storedValue;
    final reviewsRepository = MerchantReviewsRepository(
      ownerId: 'tester',
      read: (_) => storedValue,
      write: (_, value) async => storedValue = value,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyMerchantsPage(
          reviewsRepository: reviewsRepository,
          loader: (_) async => const NearbyMerchantsResult(
            currentCity: '南京市',
            merchants: [NearbyMerchant(id: 'coffee-1', name: '巷口咖啡')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('nearby-merchant-coffee-1')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nearby_review_action')));
    await tester.pumpAndSettle();

    expect(find.text('我的点评'), findsOneWidget);
    expect(find.text('巷口咖啡'), findsOneWidget);
    expect(await reviewsRepository.load(), hasLength(1));
  });
}
