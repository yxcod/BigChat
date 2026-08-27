import '../../location/data/app_location_service.dart';
import '../../location/data/nearby_places_service.dart';
import '../../location/domain/nearby_place.dart';
import '../domain/nearby_merchant.dart';
import 'baidu_poi_search_client.dart';

typedef CurrentLocationLoader = Future<CurrentPlace> Function();
typedef BaiduMerchantLoader =
    Future<List<NearbyMerchant>> Function(CurrentPlace current, String query);
typedef NearbyFallbackLoader = Future<NearbyPlacesResult> Function();

class NearbyMerchantsRepository {
  NearbyMerchantsRepository({
    CurrentLocationLoader? locationLoader,
    BaiduMerchantLoader? baiduLoader,
    NearbyFallbackLoader? fallbackLoader,
  }) : _locationLoader =
           locationLoader ?? (() => AppLocationService().locate()),
       _baiduLoader =
           baiduLoader ??
           ((current, query) =>
               BaiduPoiSearchClient().search(current: current, query: query)),
       _fallbackLoader = fallbackLoader ?? NearbyPlacesService().load;

  final CurrentLocationLoader _locationLoader;
  final BaiduMerchantLoader _baiduLoader;
  final NearbyFallbackLoader _fallbackLoader;

  Future<NearbyMerchantsResult> search({String query = ''}) async {
    final current = await _locationLoader();
    try {
      final merchants = await _baiduLoader(current, query.trim());
      return NearbyMerchantsResult(
        currentCity: _currentCityLabel(current),
        merchants: List<NearbyMerchant>.unmodifiable(merchants),
      );
    } catch (_) {
      final fallback = await _fallbackLoader();
      final normalizedQuery = query.trim().toLowerCase();
      final merchants = fallback.places
          .where(
            (place) =>
                normalizedQuery.isEmpty ||
                place.name.toLowerCase().contains(normalizedQuery) ||
                place.address.toLowerCase().contains(normalizedQuery),
          )
          .map(
            (place) => NearbyMerchant(
              id: 'system:${place.name}:${place.address}',
              name: place.name,
              address: place.address,
              distanceMeters: place.distanceMeters,
            ),
          )
          .toList(growable: false);
      return NearbyMerchantsResult(
        currentCity: fallback.currentCity,
        merchants: merchants,
      );
    }
  }

  String _currentCityLabel(CurrentPlace current) {
    final parts = current.cityRegion
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? '当前位置' : parts.last;
  }
}
