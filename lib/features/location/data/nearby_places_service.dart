import 'package:flutter/services.dart';

import '../domain/nearby_place.dart';
import 'app_location_service.dart';

typedef CurrentPlaceLoader = Future<CurrentPlace> Function();
typedef NativeNearbyPlacesLoader =
    Future<List<Object?>> Function(double latitude, double longitude);

class NearbyPlacesService {
  NearbyPlacesService({
    CurrentPlaceLoader? currentPlaceLoader,
    NativeNearbyPlacesLoader? nativeLoader,
  }) : _currentPlaceLoader =
           currentPlaceLoader ?? (() => AppLocationService().locate()),
       _nativeLoader = nativeLoader ?? _loadNativePlaces;

  static const MethodChannel _channel = MethodChannel(
    'com.yxcod.bigchat/nearby_places',
  );

  final CurrentPlaceLoader _currentPlaceLoader;
  final NativeNearbyPlacesLoader _nativeLoader;

  Future<NearbyPlacesResult> load() async {
    final current = await _currentPlaceLoader();
    final places = <NearbyPlace>[];
    try {
      final native = await _nativeLoader(current.latitude, current.longitude);
      for (final raw in native) {
        if (raw is! Map) continue;
        final map = Map<Object?, Object?>.from(raw);
        final name = map['name']?.toString().trim() ?? '';
        if (name.isEmpty || places.any((item) => item.name == name)) continue;
        final distance = map['distanceMeters'];
        places.add(
          NearbyPlace(
            name: name,
            address: map['address']?.toString().trim() ?? '',
            distanceMeters: distance is num
                ? distance.round()
                : int.tryParse(distance?.toString() ?? ''),
          ),
        );
      }
    } on MissingPluginException {
      // Non-iOS targets use the reverse-geocoded fallback below.
    } on PlatformException {
      // A temporary MapKit search failure should not block location selection.
    }
    for (final name in current.placeCandidates) {
      if (name.isNotEmpty && !places.any((item) => item.name == name)) {
        places.add(NearbyPlace(name: name, address: current.address));
      }
    }
    return NearbyPlacesResult(
      currentCity: _currentCityLabel(current),
      places: List<NearbyPlace>.unmodifiable(places),
    );
  }

  static Future<List<Object?>> _loadNativePlaces(
    double latitude,
    double longitude,
  ) async {
    final result = await _channel.invokeListMethod<Object?>('nearbyPlaces', {
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': 3000.0,
    });
    return result ?? const [];
  }

  String _currentCityLabel(CurrentPlace current) {
    final parts = current.cityRegion
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isNotEmpty) return parts.last;
    return '当前城市';
  }
}
