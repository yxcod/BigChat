import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/features/nearby/domain/nearby_merchant.dart';
import 'package:flutter_base/features/nearby/domain/merchant_review.dart';
import 'package:flutter_base/features/nearby/presentation/nearby_merchant_detail_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text']?.toString();
            return null;
          }
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': clipboardText};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  const merchant = NearbyMerchant(
    id: 'poi-1',
    name: '蓝鲸咖啡',
    address: '南京市玄武区中山东路1号',
    category: '美食;咖啡厅',
    distanceMeters: 180,
    rating: 4.8,
    phone: '025-12345678',
    openingHours: '09:00-22:00',
    price: 36,
    latitude: 32.041,
    longitude: 118.781,
  );

  testWidgets('shows complete merchant details', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyMerchantDetailPage(
          merchant: merchant,
          loader: (value) async => value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('蓝鲸咖啡'), findsOneWidget);
    expect(find.text('4.8分'), findsOneWidget);
    expect(find.text('180m'), findsOneWidget);
    expect(find.text('¥36 / 人'), findsOneWidget);
    expect(find.text('09:00-22:00'), findsOneWidget);
    expect(find.text('025-12345678'), findsOneWidget);
    expect(find.text('南京市玄武区中山东路1号'), findsOneWidget);
  });

  testWidgets('address and phone rows copy their exact values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyMerchantDetailPage(
          merchant: merchant,
          loader: (value) async => value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('南京市玄武区中山东路1号'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(clipboardText, '南京市玄武区中山东路1号');

    await tester.tap(find.text('025-12345678'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(clipboardText, '025-12345678');
  });

  testWidgets('merchant name copies on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NearbyMerchantDetailPage(
          merchant: merchant,
          loader: (value) async => value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nearby_detail_merchant_name')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(clipboardText, '蓝鲸咖啡');
    expect(find.text('商家名称已复制'), findsOneWidget);
  });

  testWidgets('uploaded review image replaces unreadable merchant artwork', (
    tester,
  ) async {
    const uploaded = MerchantReviewImage(
      ownerId: 'owner-1',
      imageName: 'merchant.png',
    );
    const pixel = <int>[
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1f,
      0x15,
      0xc4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0d,
      0x49,
      0x44,
      0x41,
      0x54,
      0x08,
      0xd7,
      0x63,
      0xf8,
      0xcf,
      0xc0,
      0xf0,
      0x1f,
      0x00,
      0x05,
      0x00,
      0x01,
      0xff,
      0x89,
      0x99,
      0x3d,
      0x1d,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4e,
      0x44,
      0xae,
      0x42,
      0x60,
      0x82,
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: NearbyMerchantDetailPage(
          merchant: merchant,
          loader: (value) async => value,
          uploadedImages: const [uploaded],
          uploadedImageProviderBuilder: (_) =>
              MemoryImage(Uint8List.fromList(pixel)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('nearby_detail_uploaded_gallery')),
      findsOneWidget,
    );
    expect(find.text('商家图片暂不可读取'), findsNothing);
  });
}
