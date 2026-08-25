import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../features/settings/data/app_settings_repository.dart';
import '../../../utils/gloabl.dart';
import '../../../utils/http.dart';

class CurrentPlace {
  const CurrentPlace({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.address,
    this.cityRegion = '',
  });
  final double latitude;
  final double longitude;
  final double accuracy;
  final String address;
  final String cityRegion;
}

class AppLocationService {
  AppLocationService({
    HttpUtil? httpUtil,
    Future<bool> Function()? locationEnabledReader,
  }) : _http = httpUtil ?? HttpUtil(),
       _locationEnabledReader = locationEnabledReader;

  final HttpUtil _http;
  final Future<bool> Function()? _locationEnabledReader;

  String get _userName => GlobalUtil().userName ?? '';

  Future<bool> isEnabledInSettings() async {
    if (_locationEnabledReader != null) {
      return _locationEnabledReader();
    }
    return (await AppSettingsRepository(
      ownerId: _userName,
    ).load()).locationEnabled;
  }

  Future<void> _requireEnabled() async {
    if (!await isEnabledInSettings()) {
      throw const LocationSharingDisabledException();
    }
  }

  /// 静默同步仅在用户已经授予权限时运行，避免应用启动时突然弹出权限请求。
  Future<void> syncIfPermitted() async {
    if (_userName.isEmpty || !await isEnabledInSettings()) return;
    if (!await Geolocator.isLocationServiceEnabled()) return;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      return;
    }
    await locate(upload: true);
  }

  /// 让服务器保存的坐标与本地总开关保持一致。
  ///
  /// 开关关闭时不会读取系统位置，只会清除服务端残留坐标；开启时仍遵循
  /// 系统定位权限，仅在权限已授予的情况下静默同步。
  Future<void> reconcileServerPreference() async {
    if (_userName.isEmpty) return;
    if (!await isEnabledInSettings()) {
      await clearServerLocation();
      return;
    }
    await syncIfPermitted();
  }

  Future<CurrentPlace> locate({
    bool upload = true,
    bool resolveAddress = true,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await _requireEnabled();
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('请先开启系统定位服务');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
        permission == LocationPermission.deniedForever
            ? '定位权限被永久拒绝，请前往系统设置开启'
            : '未获得定位权限',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ),
    );
    var address =
        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    var cityRegion = '';
    if (resolveAddress) {
      try {
        final placemarks = await Geocoding(
          locale: const Locale('zh', 'CN'),
        ).placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          address = _formatPlacemark(placemarks.first);
          cityRegion = formatCityRegion(placemarks.first);
        }
      } catch (_) {}
    }
    final place = CurrentPlace(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      address: address,
      cityRegion: cityRegion,
    );
    if (upload && _userName.isNotEmpty) await updateServer(place);
    return place;
  }

  String _formatPlacemark(Placemark value) {
    final parts =
        [
              value.administrativeArea,
              value.locality,
              value.subLocality,
              value.street,
              value.name,
            ]
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
    final unique = <String>[];
    for (final part in parts) {
      if (unique.isEmpty || !unique.last.endsWith(part)) unique.add(part);
    }
    return unique.isEmpty ? '当前位置' : unique.join('');
  }

  Future<void> updateServer(
    CurrentPlace place, {
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    // The switch may be turned off while a GPS lookup is in progress. Check
    // again at the network boundary so coordinates can never be uploaded
    // after the user disables location sharing.
    await _requireEnabled();
    final response = await _http.post(
      '/api/location/update',
      data: {
        'userName': _userName,
        'latitude': place.latitude,
        'longitude': place.longitude,
        'accuracy': place.accuracy,
      },
      cancelToken: cancelToken,
      options: timeout == null
          ? null
          : Options(sendTimeout: timeout, receiveTimeout: timeout),
    );
    if (response.data is! Map || response.data['code'] != 100) {
      throw Exception('位置同步失败');
    }
  }

  Future<int?> refreshDistance(
    String peerUserName, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final cancelToken = CancelToken();
    Future<int?> operation() async {
      // Distance calculation only needs coordinates. Reverse geocoding can be
      // slow and is intentionally skipped so one attempt stays within 5s.
      final place = await locate(
        upload: false,
        resolveAddress: false,
        timeout: timeout,
      );
      if (cancelToken.isCancelled) throw TimeoutException('距离获取超时');
      await updateServer(place, cancelToken: cancelToken, timeout: timeout);
      // Guard the distance API separately in case the preference changes
      // after the coordinate update completes.
      await _requireEnabled();
      final response = await _http.post(
        '/api/location/distance',
        data: {'userName': _userName, 'peerUserName': peerUserName},
        cancelToken: cancelToken,
        options: Options(sendTimeout: timeout, receiveTimeout: timeout),
      );
      final data = response.data;
      if (data is! Map || data['code'] != 100 || data['available'] != true) {
        return null;
      }
      final value = data['distanceMeters'];
      return value is num
          ? value.toInt()
          : int.tryParse(value?.toString() ?? '');
    }

    try {
      return await operation().timeout(
        timeout,
        onTimeout: () {
          if (!cancelToken.isCancelled) cancelToken.cancel('距离获取超时');
          throw TimeoutException('距离获取超时');
        },
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        throw TimeoutException('距离获取超时');
      }
      rethrow;
    }
  }

  Future<void> clearServerLocation() async {
    if (_userName.isEmpty) return;
    await _http.post('/api/location/clear', data: {'userName': _userName});
  }
}

class LocationSharingDisabledException implements Exception {
  const LocationSharingDisabledException();

  @override
  String toString() => '请先在设置中开启位置信息';
}

String formatCityRegion(Placemark value) {
  final province = value.administrativeArea?.trim() ?? '';
  final city = value.locality?.trim() ?? '';
  if (province.isEmpty) return city;
  if (city.isEmpty || province == city || province.endsWith(city)) {
    return province;
  }
  return '$province $city';
}

String formatDistance(int meters) {
  if (meters < 1000) return '${meters.clamp(0, 999)}米';
  if (meters < 10000) return '${(meters / 1000).toStringAsFixed(1)}公里';
  return '${(meters / 1000).round()}公里';
}
