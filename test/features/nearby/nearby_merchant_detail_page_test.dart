import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_base/features/nearby/domain/nearby_merchant.dart';
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
}
