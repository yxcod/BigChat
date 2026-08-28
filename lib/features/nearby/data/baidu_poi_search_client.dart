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
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        return await _searchOnce(current: current, query: query);
      } on StateError catch (error) {
        final authenticationPending = error.message.toString().contains(
          'PERMISSION_UNFINISHED',
        );
        if (!authenticationPending || attempt == 4) rethrow;
        // Android SDK authentication completes asynchronously after
        // SDKInitializer.initialize(). Do not turn its brief pending state
        // into a permanent system-geocoder fallback for this page load.
        await Future<void>.delayed(const Duration(milliseconds: 750));
      }
    }
    throw StateError('百度地点检索鉴权超时');
  }

  Future<List<NearbyMerchant>> _searchOnce({
    required CurrentPlace current,
    required String query,
  }) async {
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
          final merchant = _merchantFromPoi(poi);
          if (merchant == null || !seen.add(merchant.id)) continue;
          merchants.add(merchant);
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

  Future<NearbyMerchant> loadDetail(NearbyMerchant merchant) async {
    if (merchant.id.startsWith('system:')) return merchant;
    await _initialize();
    final completer = Completer<NearbyMerchant>();
    final searcher = BMFPoiDetailSearch();
    searcher.onGetPoiDetailSearchResult(
      callback: (result, errorCode) {
        if (completer.isCompleted) return;
        if (errorCode != BMFSearchErrorCode.NO_ERROR ||
            result.poiInfoList?.isNotEmpty != true) {
          completer.completeError(StateError('百度商家详情加载失败：$errorCode'));
          return;
        }
        completer.complete(
          _merchantFromPoi(result.poiInfoList!.first, fallback: merchant) ??
              merchant,
        );
      },
    );
    final started = await searcher.poiDetailSearch(
      BMFPoiDetailSearchOption(
        poiUIDs: [merchant.id],
        scope: BMFPoiSearchScopeType.DETAIL_INFORMATION,
      ),
    );
    if (!started && !completer.isCompleted) {
      completer.completeError(StateError('百度商家详情检索未能启动'));
    }
    return completer.future.timeout(const Duration(seconds: 10));
  }

  NearbyMerchant? _merchantFromPoi(BMFPoiInfo poi, {NearbyMerchant? fallback}) {
    final name = poi.name?.trim() ?? fallback?.name ?? '';
    if (name.isEmpty) return null;
    final detail = poi.detailInfo;
    final id = poi.uid?.trim().isNotEmpty == true
        ? poi.uid!.trim()
        : fallback?.id ?? '${poi.pt?.latitude},${poi.pt?.longitude}:$name';
    return NearbyMerchant(
      id: id,
      name: name,
      address: poi.address?.trim().isNotEmpty == true
          ? poi.address!.trim()
          : fallback?.address ?? '',
      category: (detail?.tag ?? poi.tag ?? fallback?.category ?? '').trim(),
      distanceMeters:
          detail?.distance ?? poi.distance ?? fallback?.distanceMeters,
      rating: detail?.overallRating ?? fallback?.rating,
      imageUrl: fallback?.imageUrl ?? '',
      imageUrls: fallback?.imageUrls ?? const [],
      phone: poi.phone?.trim().isNotEmpty == true
          ? poi.phone!.trim()
          : fallback?.phone ?? '',
      openingHours: detail?.openingHours?.trim().isNotEmpty == true
          ? detail!.openingHours!.trim()
          : fallback?.openingHours ?? '',
      price: detail?.price ?? fallback?.price,
      detailUrl: detail?.detailURL?.trim().isNotEmpty == true
          ? detail!.detailURL!.trim()
          : fallback?.detailUrl ?? '',
      imageCount: detail?.imageNumber ?? fallback?.imageCount ?? 0,
      latitude: poi.pt?.latitude ?? fallback?.latitude,
      longitude: poi.pt?.longitude ?? fallback?.longitude,
    );
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    BMFMapSDK.setAgreePrivacy(true);
    if (Platform.isIOS) {
      final configuredAk = _iosAk.trim().isNotEmpty
          ? _iosAk.trim()
          : (await _androidSetupChannel.invokeMethod<String>(
                  'getApiKey',
                ))?.trim() ??
                '';
      if (configuredAk.isEmpty) {
        throw StateError('尚未配置 iOS 百度地图 AK');
      }
      BMFMapSDK.setApiKeyAndCoordType(configuredAk, BMF_COORD_TYPE.BD09LL);
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
