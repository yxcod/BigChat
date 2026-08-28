import 'package:flutter_base/features/location/data/app_location_service.dart';
import 'package:flutter_base/features/location/domain/nearby_place.dart';
import 'package:flutter_base/features/nearby/data/nearby_merchants_repository.dart';
import 'package:flutter_base/features/nearby/domain/nearby_merchant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const current = CurrentPlace(
    latitude: 32.04,
    longitude: 118.78,
    accuracy: 5,
    address: '江苏省南京市玄武区中山东路',
    cityRegion: '江苏省 南京市',
    placeCandidates: ['中山东路'],
  );

  test('returns Baidu nearby merchant results', () async {
    final repository = NearbyMerchantsRepository(
      locationLoader: () async => current,
      baiduLoader: (_, query) async => [
        NearbyMerchant(
          id: 'poi-1',
          name: '$query咖啡店',
          address: '中山东路1号',
          category: '美食;咖啡厅',
          distanceMeters: 180,
        ),
      ],
      fallbackLoader: () => throw StateError('fallback should not run'),
    );

    final result = await repository.search(query: '蓝鲸');

    expect(result.currentCity, '南京市');
    expect(result.merchants.single.name, '蓝鲸咖啡店');
    expect(result.merchants.single.distanceMeters, 180);
  });

  test('sorts nearby merchants from nearest to farthest', () async {
    final repository = NearbyMerchantsRepository(
      locationLoader: () async => current,
      baiduLoader: (_, _) async => const [
        NearbyMerchant(id: 'unknown', name: '未知距离'),
        NearbyMerchant(id: 'far', name: '远处商家', distanceMeters: 900),
        NearbyMerchant(id: 'near', name: '近处商家', distanceMeters: 80),
        NearbyMerchant(id: 'middle', name: '中间商家', distanceMeters: 260),
      ],
      fallbackLoader: () => throw StateError('fallback should not run'),
    );

    final result = await repository.search();

    expect(result.merchants.map((item) => item.id), [
      'near',
      'middle',
      'far',
      'unknown',
    ]);
  });

  test(
    'falls back to native nearby places when Baidu is unavailable',
    () async {
      final repository = NearbyMerchantsRepository(
        locationLoader: () async => current,
        baiduLoader: (_, _) => throw StateError('AK missing'),
        fallbackLoader: () async => const NearbyPlacesResult(
          currentCity: '南京市',
          places: [
            NearbyPlace(
              name: '南京博物院',
              address: '中山东路321号',
              distanceMeters: 260,
            ),
          ],
        ),
      );

      final result = await repository.search(query: '博物院');

      expect(result.merchants.single.name, '南京博物院');
      expect(result.merchants.single.distanceMeters, 260);
    },
  );
}
