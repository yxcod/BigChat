import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../core/cache/app_image_cache.dart';
import '../data/merchant_reviews_repository.dart';
import '../domain/merchant_review.dart';
import '../domain/nearby_merchant.dart';
import 'merchant_review_comments_page.dart';
import 'nearby_merchant_detail_page.dart';

class MerchantReviewsPage extends StatefulWidget {
  const MerchantReviewsPage({
    super.key,
    this.repository,
    this.userId,
    this.pageTitle,
  });

  final MerchantReviewsRepository? repository;
  final String? userId;
  final String? pageTitle;

  @override
  State<MerchantReviewsPage> createState() => _MerchantReviewsPageState();
}

class _MerchantReviewsPageState extends State<MerchantReviewsPage> {
  static const _filters = ['全部', '美食', '玩乐', '景点', '咖啡', '购物'];

  late final MerchantReviewsRepository _repository;
  final TextEditingController _searchController = TextEditingController();
  List<MerchantReview> _reviews = const [];
  String _selectedFilter = '全部';
  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? MerchantReviewsRepository(ownerId: widget.userId);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final reviews = await _repository.load();
    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _loading = false;
    });
  }

  List<MerchantReview> get _visibleReviews {
    final categoryFiltered = _selectedFilter == '全部'
        ? _reviews
        : _reviews
              .where(
                (review) =>
                    _merchantCategory(review.merchant) == _selectedFilter,
              )
              .toList(growable: false);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? categoryFiltered
        : categoryFiltered.where((review) {
            final merchant = review.merchant;
            return merchant.name.toLowerCase().contains(query) ||
                merchant.category.toLowerCase().contains(query) ||
                merchant.address.toLowerCase().contains(query);
          });
    return sortMerchantReviews(filtered);
  }

  Future<void> _toggleReaction(
    MerchantReview review,
    MerchantReviewReaction reaction,
  ) async {
    await _repository.setReaction(review.merchant.id, reaction);
    await _load();
  }

  Future<void> _openComments(MerchantReview review) async {
    await Navigator.of(context).push<MerchantReview>(
      MaterialPageRoute(
        builder: (_) =>
            MerchantReviewCommentsPage(review: review, repository: _repository),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: context.appSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: _searching
            ? TextField(
                key: const ValueKey('merchant_reviews_search_field'),
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: TextStyle(color: context.appTextPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: '搜索商家',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Text(
                widget.pageTitle ?? '我的点评',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
        actions: [
          IconButton(
            key: const ValueKey('merchant_reviews_search_action'),
            tooltip: _searching ? '关闭搜索' : '搜索',
            onPressed: () {
              setState(() {
                if (_searching) _searchController.clear();
                _searching = !_searching;
              });
            },
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.appDivider),
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: context.appSurface,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 9),
      child: Column(
        children: [
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final selected = filter == _selectedFilter;
                return ChoiceChip(
                  key: ValueKey('merchant_review_filter_$filter'),
                  label: Text(filter),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : context.appTextPrimary,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  backgroundColor: context.appSearchBackground,
                  selectedColor: AppColors.primary,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '按口碑排序',
              style: TextStyle(color: context.appTextSecondary, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.4,
        ),
      );
    }
    final reviews = _visibleReviews;
    if (reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 46,
              color: context.appTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              _selectedFilter == '全部' ? '还没有商家，去附近添加点评吧' : '该分类下还没有商家',
              style: TextStyle(color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.separated(
        key: const ValueKey('merchant_reviews_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        itemCount: reviews.length,
        separatorBuilder: (_, _) => const SizedBox(height: 11),
        itemBuilder: (context, index) {
          final review = reviews[index];
          return _ReviewMerchantCard(
            review: review,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    NearbyMerchantDetailPage(merchant: review.merchant),
              ),
            ),
            onLike: () => _toggleReaction(review, MerchantReviewReaction.like),
            onDislike: () =>
                _toggleReaction(review, MerchantReviewReaction.dislike),
            onComment: () => _openComments(review),
          );
        },
      ),
    );
  }
}

class _ReviewMerchantCard extends StatelessWidget {
  const _ReviewMerchantCard({
    required this.review,
    required this.onTap,
    required this.onLike,
    required this.onDislike,
    required this.onComment,
  });

  final MerchantReview review;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    final merchant = review.merchant;
    return Material(
      key: ValueKey('merchant-review-${merchant.id}'),
      color: context.appSurface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReviewMerchantImage(merchant: merchant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 92,
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _CategoryBadge(
                                label: _merchantCategory(merchant),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFFA5A8AD),
                                size: 21,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _merchantSubtitle(merchant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            merchant.address.isEmpty
                                ? '暂无详细地址'
                                : merchant.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appTextSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: context.appDivider,
          ),
          SizedBox(
            height: 46,
            child: Row(
              children: [
                Expanded(
                  child: _ReviewMetricButton(
                    key: ValueKey('merchant_review_like_${merchant.id}'),
                    icon: review.reaction == MerchantReviewReaction.like
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                    label: '赞 ${review.likes}',
                    color: AppColors.primary,
                    onTap: onLike,
                  ),
                ),
                _MetricDivider(color: context.appDivider),
                Expanded(
                  child: _ReviewMetricButton(
                    key: ValueKey('merchant_review_dislike_${merchant.id}'),
                    icon: review.reaction == MerchantReviewReaction.dislike
                        ? Icons.thumb_down_rounded
                        : Icons.thumb_down_outlined,
                    label: '踩 ${review.dislikes}',
                    color: AppColors.danger,
                    onTap: onDislike,
                  ),
                ),
                _MetricDivider(color: context.appDivider),
                Expanded(
                  child: _ReviewMetricButton(
                    key: ValueKey('merchant_review_comment_${merchant.id}'),
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '评论 ${review.comments.length}',
                    color: context.appTextSecondary,
                    onTap: onComment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMerchantImage extends StatelessWidget {
  const _ReviewMerchantImage({required this.merchant});

  final NearbyMerchant merchant;

  @override
  Widget build(BuildContext context) {
    final images = merchant.availableImageUrls;
    final fallback = Container(
      color: const Color(0xFF71BE99),
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox.square(
        dimension: 92,
        child: images.isEmpty
            ? fallback
            : CachedNetworkImage(
                cacheManager: AppImageCache.manager,
                imageUrl: images.first,
                cacheKey: AppImageCache.cacheKey(images.first),
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F7EE),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ReviewMetricButton extends StatelessWidget {
  const _ReviewMetricButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.appTextSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 18, color: color);
}

String _merchantCategory(NearbyMerchant merchant) {
  final value = '${merchant.category} ${merchant.name}';
  if (value.contains('咖啡')) return '咖啡';
  if (value.contains('景点') ||
      value.contains('公园') ||
      value.contains('旅游') ||
      value.contains('博物馆')) {
    return '景点';
  }
  if (value.contains('娱乐') ||
      value.contains('游乐') ||
      value.contains('电影') ||
      value.contains('KTV') ||
      value.contains('电玩')) {
    return '玩乐';
  }
  if (value.contains('购物') || value.contains('商场') || value.contains('超市')) {
    return '购物';
  }
  return '美食';
}

String _merchantSubtitle(NearbyMerchant merchant) {
  final category = merchant.category.trim().isEmpty
      ? _merchantCategory(merchant)
      : merchant.category.split(RegExp(r'[;,/]')).first.trim();
  final meters = merchant.distanceMeters;
  if (meters == null) return category;
  final distance = meters < 1000
      ? '${meters}m'
      : '${(meters / 1000).toStringAsFixed(1)}km';
  return '$category · $distance';
}
