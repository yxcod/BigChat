import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

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
        merchants: _sortByDistance(merchants),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Baidu merchant search failed; using system location fallback',
        name: 'NearbyMerchantsRepository',
        error: error,
        stackTrace: stackTrace,
      );
      debugPrint('Baidu merchant search failed: $error');
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
        merchants: _sortByDistance(merchants),
      );
    }
  }

  List<NearbyMerchant> _sortByDistance(Iterable<NearbyMerchant> source) {
    final merchants = source.toList(growable: false);
    merchants.sort((left, right) {
      final leftDistance = left.distanceMeters;
      final rightDistance = right.distanceMeters;
      if (leftDistance == null && rightDistance == null) {
        return left.name.compareTo(right.name);
      }
      if (leftDistance == null) return 1;
      if (rightDistance == null) return -1;
      final distance = leftDistance.compareTo(rightDistance);
      return distance != 0 ? distance : left.name.compareTo(right.name);
    });
    return List<NearbyMerchant>.unmodifiable(merchants);
  }

  String _currentCityLabel(CurrentPlace current) {
    final parts = current.cityRegion
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? '当前位置' : parts.last;
  }
}
