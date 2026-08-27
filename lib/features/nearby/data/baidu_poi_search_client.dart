import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_baidu_mapapi_base/flutter_baidu_mapapi_base.dart';
import 'package:flutter_baidu_mapapi_search/flutter_baidu_mapapi_search.dart';
import 'package:flutter_baidu_mapapi_utils/flutter_baidu_mapapi_utils.dart';

import '../../location/data/app_location_service.dart';
import '../domain/nearby_merchant.dart';

class BaiduPoiSearchClient {
  static const _androidSetupChannel = MethodChannel(
    'com.yxcod.bigchat/baidu_lbs_setup',
  );
  static const _iosAk = String.fromEnvironment('BAIDU_IOS_AK');

  bool _initialized = false;

  Future<List<NearbyMerchant>> search({
    required CurrentPlace current,
    required String query,
  }) async {
    await _initialize();
    final converted = await BMFCalculateUtils.coordConvert(
      coordinate: BMFCoordinate(current.latitude, current.longitude),
      fromType: BMF_COORD_TYPE.GPS,
      toType: BMF_COORD_TYPE.BD09LL,
    );
    if (converted == null ||
        converted.latitude == 0 ||
        converted.longitude == 0) {
      throw StateError('百度坐标转换失败');
    }

    final completer = Completer<List<NearbyMerchant>>();
    final searcher = BMFPoiNearbySearch();
    searcher.onGetPoiNearbySearchResult(
      callback: (result, errorCode) {
        if (completer.isCompleted) return;
        if (errorCode != BMFSearchErrorCode.NO_ERROR) {
          completer.completeError(StateError('百度地点检索失败：$errorCode'));
          return;
        }
        final seen = <String>{};
        final merchants = <NearbyMerchant>[];
        for (final poi in result.poiInfoList ?? const <BMFPoiInfo>[]) {
          final name = poi.name?.trim() ?? '';
          if (name.isEmpty) continue;
          final id = poi.uid?.trim().isNotEmpty == true
              ? poi.uid!.trim()
              : '${poi.pt?.latitude},${poi.pt?.longitude}:$name';
          if (!seen.add(id)) continue;
          merchants.add(
            NearbyMerchant(
              id: id,
              name: name,
              address: poi.address?.trim() ?? '',
              category: (poi.detailInfo?.tag ?? poi.tag ?? '').trim(),
              distanceMeters: poi.detailInfo?.distance ?? poi.distance,
              rating: poi.detailInfo?.overallRating,
              latitude: poi.pt?.latitude,
              longitude: poi.pt?.longitude,
            ),
          );
        }
        completer.complete(merchants);
      },
    );

    final keyword = query.trim();
    final started = await searcher.poiNearbySearch(
      BMFPoiNearbySearchOption(
        keywords: keyword.isEmpty
            ? const ['美食', '购物', '生活服务', '休闲娱乐', '酒店']
            : [keyword],
        location: converted,
        radius: 5000,
        isRadiusLimit: true,
        scope: BMFPoiSearchScopeType.DETAIL_INFORMATION,
        pageSize: 20,
      ),
    );
    if (!started && !completer.isCompleted) {
      completer.completeError(StateError('百度地点检索未能启动'));
    }
    return completer.future.timeout(const Duration(seconds: 10));
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    BMFMapSDK.setAgreePrivacy(true);
    if (Platform.isIOS) {
      if (_iosAk.trim().isEmpty) {
        throw StateError('尚未配置 iOS 百度地图 AK');
      }
      BMFMapSDK.setApiKeyAndCoordType(_iosAk, BMF_COORD_TYPE.BD09LL);
    } else if (Platform.isAndroid) {
      final configured = await _androidSetupChannel.invokeMethod<bool>(
        'initialize',
      );
      if (configured != true) {
        throw StateError('尚未配置 Android 百度地图 AK');
      }
      BMFMapSDK.setCoordType(BMF_COORD_TYPE.BD09LL);
    } else {
      throw UnsupportedError('当前平台暂不支持百度地点检索');
    }
    _initialized = true;
  }
}
