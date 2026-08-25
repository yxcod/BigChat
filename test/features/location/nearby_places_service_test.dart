import 'package:flutter_base/features/location/data/app_location_service.dart';
import 'package:flutter_base/features/location/data/nearby_places_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads exact nearby place names and keeps current city first', () async {
    final service = NearbyPlacesService(
      currentPlaceLoader: () async => const CurrentPlace(
        latitude: 32.04,
        longitude: 118.78,
        accuracy: 5,
        address: '江苏省南京市玄武区中山东路',
        cityRegion: '江苏省 南京市',
        placeCandidates: ['中山东路'],
      ),
      nativeLoader: (_, _) async => [
        {
          'name': '南京博物院',
          'address': '江苏省南京市玄武区中山东路321号',
          'distanceMeters': 260,
        },
      ],
    );

    final result = await service.load();

    expect(result.currentCity, '南京市');
    expect(result.places.map((place) => place.name), ['南京博物院', '中山东路']);
    expect(result.places.first.distanceMeters, 260);
  });
}
