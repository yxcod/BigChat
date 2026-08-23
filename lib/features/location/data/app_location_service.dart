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
  });
  final double latitude;
  final double longitude;
  final double accuracy;
  final String address;
}

class AppLocationService {
  AppLocationService({HttpUtil? httpUtil}) : _http = httpUtil ?? HttpUtil();
  final HttpUtil _http;

  String get _userName => GlobalUtil().userName ?? '';

  Future<bool> isEnabledInSettings() async {
    return (await AppSettingsRepository(
      ownerId: _userName,
    ).load()).locationEnabled;
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

  Future<CurrentPlace> locate({bool upload = true}) async {
    if (!await isEnabledInSettings()) {
      throw Exception('请先在设置中开启位置信息');
    }
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
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    var address =
        '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
    try {
      final placemarks = await Geocoding(
        locale: const Locale('zh', 'CN'),
      ).placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) address = _formatPlacemark(placemarks.first);
    } catch (_) {}
    final place = CurrentPlace(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      address: address,
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

  Future<void> updateServer(CurrentPlace place) async {
    final response = await _http.post(
      '/api/location/update',
      data: {
        'userName': _userName,
        'latitude': place.latitude,
        'longitude': place.longitude,
        'accuracy': place.accuracy,
      },
    );
    if (response.data is! Map || response.data['code'] != 100) {
      throw Exception('位置同步失败');
    }
  }

  Future<int?> refreshDistance(String peerUserName) async {
    await locate(upload: true);
    final response = await _http.post(
      '/api/location/distance',
      data: {'userName': _userName, 'peerUserName': peerUserName},
    );
    final data = response.data;
    if (data is! Map || data['code'] != 100 || data['available'] != true) {
      return null;
    }
    final value = data['distanceMeters'];
    return value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
  }

  Future<void> clearServerLocation() async {
    if (_userName.isEmpty) return;
    await _http.post('/api/location/clear', data: {'userName': _userName});
  }
}

String formatDistance(int meters) {
  if (meters < 1000) return '${meters.clamp(0, 999)}米';
  if (meters < 10000) return '${(meters / 1000).toStringAsFixed(1)}公里';
  return '${(meters / 1000).round()}公里';
}
