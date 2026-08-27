import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../core/cache/app_image_cache.dart';
import '../data/nearby_merchants_repository.dart';
import '../domain/nearby_merchant.dart';

typedef NearbyMerchantsLoader =
    Future<NearbyMerchantsResult> Function(String query);

class NearbyMerchantsPage extends StatefulWidget {
  const NearbyMerchantsPage({super.key, this.loader});

  final NearbyMerchantsLoader? loader;

  @override
  State<NearbyMerchantsPage> createState() => _NearbyMerchantsPageState();
}

class _NearbyMerchantsPageState extends State<NearbyMerchantsPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  NearbyMerchantsResult? _result;
  Object? _error;
  bool _loading = true;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _load([String? query]) async {
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await (widget.loader ?? _defaultLoader)(
        query ?? _searchController.text,
      );
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<NearbyMerchantsResult> _defaultLoader(String query) {
    return NearbyMerchantsRepository().search(query: query);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), () => _load(value));
    setState(() {});
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    _load('');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _searchFocusNode.unfocus,
      child: Scaffold(
        backgroundColor: context.appPageBackground,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: context.appSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            '附近',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: context.appDivider),
          ),
        ),
        body: Column(
          children: [
            _buildSearchArea(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchArea() {
    final city = _result?.currentCity;
    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('nearby_merchant_search_field'),
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onQueryChanged,
            onSubmitted: _load,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索附近商家',
              prefixIcon: const Icon(Icons.search_rounded, size: 21),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空',
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                    ),
              filled: true,
              fillColor: context.appSearchBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          if (city != null && city.isNotEmpty) ...[
            const SizedBox(height: 11),
            Row(
              children: [
                const Icon(
                  Icons.near_me_outlined,
                  color: AppColors.primary,
                  size: 17,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '$city · 5公里内',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _loading ? null : () => _load(),
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '刷新位置',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _result == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.4,
        ),
      );
    }
    if (_error != null && _result == null) {
      return _NearbyErrorState(error: _error!, onRetry: _load);
    }
    final merchants = _result?.merchants ?? const <NearbyMerchant>[];
    if (merchants.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            Icon(
              Icons.storefront_outlined,
              size: 48,
              color: context.appTextSecondary,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _searchController.text.trim().isEmpty
                    ? '附近暂时没有可展示的商家'
                    : '没有找到相关商家',
                style: TextStyle(color: context.appTextSecondary),
              ),
            ),
          ],
        ),
      );
    }
    return Stack(
      children: [
        RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: ListView.separated(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: merchants.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _MerchantCard(merchant: merchants[index]),
          ),
        ),
        if (_loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primary,
            ),
          ),
      ],
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({required this.merchant});

  final NearbyMerchant merchant;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('nearby-merchant-${merchant.id}'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MerchantImage(merchant: merchant),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 86,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          merchant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (merchant.distanceMeters != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatDistance(merchant.distanceMeters!),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      if (merchant.rating != null) ...[
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB547),
                          size: 16,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          merchant.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFFE59520),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          merchant.category.isEmpty
                              ? '附近商家'
                              : merchant.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: context.appTextSecondary,
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          merchant.address.isEmpty
                              ? '暂无详细地址'
                              : merchant.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

class _MerchantImage extends StatelessWidget {
  const _MerchantImage({required this.merchant});

  final NearbyMerchant merchant;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: _categoryColor(merchant.category),
      alignment: Alignment.center,
      child: Icon(
        _categoryIcon(merchant.category),
        color: Colors.white,
        size: 34,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 86,
        height: 86,
        child: merchant.imageUrl.isEmpty
            ? fallback
            : CachedNetworkImage(
                cacheManager: AppImageCache.manager,
                imageUrl: merchant.imageUrl,
                cacheKey: AppImageCache.cacheKey(merchant.imageUrl),
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    if (category.contains('美食') || category.contains('餐饮')) {
      return Icons.restaurant_rounded;
    }
    if (category.contains('酒店')) return Icons.hotel_rounded;
    if (category.contains('购物')) return Icons.shopping_bag_rounded;
    if (category.contains('娱乐')) return Icons.sports_esports_rounded;
    return Icons.storefront_rounded;
  }

  Color _categoryColor(String category) {
    if (category.contains('美食') || category.contains('餐饮')) {
      return const Color(0xFFF29B68);
    }
    if (category.contains('酒店')) return const Color(0xFF829BE9);
    if (category.contains('购物')) return const Color(0xFFE486A8);
    if (category.contains('娱乐')) return const Color(0xFF8E83DD);
    return const Color(0xFF65B995);
  }
}

class _NearbyErrorState extends StatelessWidget {
  const _NearbyErrorState({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function([String? query]) onRetry;

  @override
  Widget build(BuildContext context) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    final isLocationError = raw.contains('位置') || raw.contains('定位');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocationError
                  ? Icons.location_off_outlined
                  : Icons.store_mall_directory_outlined,
              size: 46,
              color: context.appTextSecondary,
            ),
            const SizedBox(height: 13),
            Text(
              raw.isEmpty ? '附近商家加载失败' : raw,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appTextSecondary),
            ),
            const SizedBox(height: 15),
            OutlinedButton(
              onPressed: () => onRetry(),
              child: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }
}
