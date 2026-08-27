import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../core/cache/app_image_cache.dart';
import '../data/merchant_reviews_repository.dart';
import '../data/nearby_merchants_repository.dart';
import '../domain/nearby_merchant.dart';
import 'merchant_category_placeholder.dart';
import 'merchant_reviews_page.dart';
import 'nearby_merchant_detail_page.dart';

typedef NearbyMerchantsLoader =
    Future<NearbyMerchantsResult> Function(String query);

class NearbyMerchantsPage extends StatefulWidget {
  const NearbyMerchantsPage({super.key, this.loader, this.reviewsRepository});

  final NearbyMerchantsLoader? loader;
  final MerchantReviewsRepository? reviewsRepository;

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
  late final MerchantReviewsRepository _reviewsRepository;
  Set<String> _reviewedMerchantIds = const {};

  @override
  void initState() {
    super.initState();
    _reviewsRepository =
        widget.reviewsRepository ?? MerchantReviewsRepository();
    _load();
    _loadReviewedMerchantIds();
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

  Future<void> _loadReviewedMerchantIds() async {
    final reviews = await _reviewsRepository.load();
    if (!mounted) return;
    setState(() {
      _reviewedMerchantIds = reviews.map((item) => item.merchant.id).toSet();
    });
  }

  Future<void> _openReviews() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantReviewsPage(repository: _reviewsRepository),
      ),
    );
    await _loadReviewedMerchantIds();
  }

  Future<void> _addToReviews(NearbyMerchant merchant) async {
    if (_reviewedMerchantIds.contains(merchant.id)) return;
    await _reviewsRepository.addMerchant(merchant);
    if (!mounted) return;
    setState(() {
      _reviewedMerchantIds = {..._reviewedMerchantIds, merchant.id};
    });
    await _openReviews();
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
          actions: [
            TextButton(
              key: const ValueKey('nearby_reviews_entry'),
              onPressed: _openReviews,
              child: const Text(
                '点评',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 5),
          ],
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
            itemBuilder: (context, index) {
              final merchant = merchants[index];
              final alreadyAdded = _reviewedMerchantIds.contains(merchant.id);
              return _MerchantReviewSwipeCell(
                alreadyAdded: alreadyAdded,
                onReview: () => _addToReviews(merchant),
                child: _MerchantCard(
                  merchant: merchant,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          NearbyMerchantDetailPage(merchant: merchant),
                    ),
                  ),
                ),
              );
            },
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

class _MerchantReviewSwipeCell extends StatefulWidget {
  const _MerchantReviewSwipeCell({
    required this.child,
    required this.alreadyAdded,
    required this.onReview,
  });

  final Widget child;
  final bool alreadyAdded;
  final VoidCallback onReview;

  @override
  State<_MerchantReviewSwipeCell> createState() =>
      _MerchantReviewSwipeCellState();
}

class _MerchantReviewSwipeCellState extends State<_MerchantReviewSwipeCell>
    with SingleTickerProviderStateMixin {
  static const double _actionExtent = 72;
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    )..addListener(() => setState(() => _offset = _animation.value));
    _animation = const AlwaysStoppedAnimation(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _controller.stop();
    _animation = Tween<double>(
      begin: _offset,
      end: target,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward(from: 0);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.stop();
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(0.0, _actionExtent);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldOpen = velocity > 250
        ? true
        : velocity < -250
        ? false
        : _offset >= _actionExtent * 0.42;
    _animateTo(shouldOpen ? _actionExtent : 0);
  }

  void _handleReview() {
    if (widget.alreadyAdded) return;
    _animateTo(0);
    widget.onReview();
  }

  @override
  Widget build(BuildContext context) {
    final open = _offset > 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          if (open)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: _actionExtent,
                  child: Material(
                    color: widget.alreadyAdded
                        ? const Color(0xFFAEB3B8)
                        : AppColors.primary,
                    child: InkWell(
                      key: ValueKey(
                        widget.alreadyAdded
                            ? 'nearby_review_added_action'
                            : 'nearby_review_action',
                      ),
                      onTap: widget.alreadyAdded ? null : _handleReview,
                      child: Center(
                        child: Text(
                          widget.alreadyAdded ? '已点评' : '点评',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_offset, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              onTap: open ? () => _animateTo(0) : null,
              child: AbsorbPointer(absorbing: open, child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  const _MerchantCard({required this.merchant, required this.onTap});

  final NearbyMerchant merchant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('nearby-merchant-${merchant.id}'),
      color: context.appSurface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 19,
                            color: Color(0xFFA3A6AB),
                          ),
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
        ),
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
    final images = merchant.availableImageUrls;
    final imageUrl = images.isEmpty ? null : images.first;
    final fallback = MerchantCategoryPlaceholder(merchant: merchant);
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 86,
        height: 86,
        child: imageUrl == null
            ? fallback
            : CachedNetworkImage(
                cacheManager: AppImageCache.manager,
                imageUrl: imageUrl,
                cacheKey: AppImageCache.cacheKey(imageUrl),
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
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
