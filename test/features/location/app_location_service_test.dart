import 'package:flutter_base/features/location/data/app_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  test('location sharing is enabled by default through app settings', () async {
    final service = AppLocationService(locationEnabledReader: () async => true);

    expect(await service.isEnabledInSettings(), isTrue);
  });

  test(
    'disabled sharing blocks coordinate uploads before network use',
    () async {
      final service = AppLocationService(
        locationEnabledReader: () async => false,
      );
      const place = CurrentPlace(
        latitude: 39.9042,
        longitude: 116.4074,
        accuracy: 5,
        address: '北京市',
      );

      await expectLater(
        service.updateServer(place),
        throwsA(isA<LocationSharingDisabledException>()),
      );
    },
  );

  test(
    'disabled sharing blocks distance lookup before requesting GPS',
    () async {
      final service = AppLocationService(
        locationEnabledReader: () async => false,
      );

      await expectLater(
        service.refreshDistance('bob'),
        throwsA(isA<LocationSharingDisabledException>()),
      );
    },
  );

  test('distance is displayed in exact meters below one kilometer', () {
    expect(formatDistance(0), '0米');
    expect(formatDistance(328), '328米');
    expect(formatDistance(999), '999米');
  });

  test('longer distances use readable kilometer units', () {
    expect(formatDistance(1250), '1.3公里');
    expect(formatDistance(12500), '13公里');
  });

  test('profile location only keeps province and city', () {
    expect(
      formatCityRegion(
        const Placemark(
          administrativeArea: '山东省',
          locality: '济南市',
          subLocality: '历下区',
          street: '某街道',
        ),
      ),
      '山东省 济南市',
    );
    expect(
      formatCityRegion(
        const Placemark(administrativeArea: '北京市', locality: '北京市'),
      ),
      '北京市',
    );
  });

  test('nearby fallback names strip province city and district prefixes', () {
    expect(
      compactPlacemarkNames(
        const Placemark(
          country: '中国',
          administrativeArea: '江苏省',
          locality: '南京市',
          subLocality: '玄武区',
          name: '江苏省南京市玄武区中山东路305号',
          street: '南京市玄武区中山东路',
          thoroughfare: '中山东路',
        ),
      ),
      ['中山东路305号', '中山东路'],
    );
  });
}
