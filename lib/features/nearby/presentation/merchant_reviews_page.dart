import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../core/cache/app_image_cache.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../utils/gloabl.dart';
import '../../../utils/storageUtil.dart';
import '../data/merchant_review_image_uploader.dart';
import '../data/merchant_reviews_repository.dart';
import '../domain/merchant_review.dart';
import '../domain/nearby_merchant.dart';
import 'merchant_category_placeholder.dart';
import 'merchant_review_comments_page.dart';
import 'nearby_merchant_detail_page.dart';

class MerchantReviewsPage extends StatefulWidget {
  const MerchantReviewsPage({
    super.key,
    this.repository,
    this.userId,
    this.pageTitle,
    this.allowRemoval,
    this.merchantImageProviderBuilder,
  });

  final MerchantReviewsRepository? repository;
  final String? userId;
  final String? pageTitle;
  final bool? allowRemoval;
  final ImageProvider Function(MerchantReviewImage image)?
  merchantImageProviderBuilder;

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
  final Set<String> _uploadingMerchantIds = <String>{};
  late final bool _canRemove;
  late final MerchantReviewImageUploader _imageUploader;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? MerchantReviewsRepository(ownerId: widget.userId);
    _imageUploader = ServerMerchantReviewImageUploader();
    final currentUserId = StorageUtil.getUserId();
    _canRemove =
        widget.allowRemoval ??
        (widget.userId == null || widget.userId == currentUserId);
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

  Future<void> _removeReview(MerchantReview review) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('移除已收录商家'),
        content: Text('确定将“${review.merchant.name}”从点评系统中移除吗？相关点赞、踩和评论也会一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('confirm_remove_merchant_review'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.removeMerchant(review.merchant.id);
      if (!mounted) return;
      setState(() {
        _reviews = _reviews
            .where((item) => item.merchant.id != review.merchant.id)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已移除该商家')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('移除失败：$error')));
    }
  }

  Future<void> _uploadMerchantImages(MerchantReview review) async {
    if (_uploadingMerchantIds.contains(review.merchant.id)) return;
    final replaceExisting = review.uploadedImages.length >= 4;
    final remaining = replaceExisting ? 4 : 4 - review.uploadedImages.length;
    final picked = await ImagePicker().pickMultiImage(
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (!mounted || picked.isEmpty) return;
    final userId = GlobalUtil().userName?.trim() ?? '';
    if (userId.isEmpty) return;
    setState(() => _uploadingMerchantIds.add(review.merchant.id));
    try {
      final imageNames = replaceExisting
          ? <String>[]
          : review.uploadedImages.map((item) => item.imageName).toList();
      for (final image in picked.take(remaining)) {
        imageNames.add(
          await _imageUploader.upload(authorId: userId, localPath: image.path),
        );
      }
      await _repository.setMerchantImages(review.merchant.id, imageNames);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商家图片已更新')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片上传失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _uploadingMerchantIds.remove(review.merchant.id));
      }
    }
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
                builder: (_) => NearbyMerchantDetailPage(
                  merchant: review.merchant,
                  uploadedImages: review.uploadedImages,
                  uploadedImageProviderBuilder:
                      widget.merchantImageProviderBuilder,
                ),
              ),
            ),
            onLike: () => _toggleReaction(review, MerchantReviewReaction.like),
            onDislike: () =>
                _toggleReaction(review, MerchantReviewReaction.dislike),
            onComment: () => _openComments(review),
            onUploadImages: _canRemove
                ? () => _uploadMerchantImages(review)
                : null,
            uploadingImages: _uploadingMerchantIds.contains(review.merchant.id),
            merchantImageProviderBuilder: widget.merchantImageProviderBuilder,
            onRemove: _canRemove ? () => _removeReview(review) : null,
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
    this.onUploadImages,
    this.uploadingImages = false,
    this.merchantImageProviderBuilder,
    this.onRemove,
  });

  final MerchantReview review;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onComment;
  final VoidCallback? onUploadImages;
  final bool uploadingImages;
  final ImageProvider Function(MerchantReviewImage image)?
  merchantImageProviderBuilder;
  final VoidCallback? onRemove;

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
                      height: 94,
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
                              if (onRemove == null)
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFFA5A8AD),
                                  size: 21,
                                )
                              else
                                PopupMenuButton<String>(
                                  key: ValueKey(
                                    'merchant_review_menu_${merchant.id}',
                                  ),
                                  tooltip: '更多操作',
                                  padding: EdgeInsets.zero,
                                  child: const SizedBox(
                                    width: 28,
                                    height: 24,
                                    child: Icon(
                                      Icons.more_horiz_rounded,
                                      color: Color(0xFFA5A8AD),
                                      size: 21,
                                    ),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'upload') {
                                      onUploadImages?.call();
                                    }
                                    if (value == 'remove') onRemove?.call();
                                  },
                                  itemBuilder: (_) => [
                                    if (onUploadImages != null)
                                      PopupMenuItem(
                                        value: 'upload',
                                        enabled: !uploadingImages,
                                        child: Row(
                                          children: [
                                            uploadingImages
                                                ? const SizedBox.square(
                                                    dimension: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons
                                                        .add_photo_alternate_outlined,
                                                    color: AppColors.primary,
                                                    size: 20,
                                                  ),
                                            const SizedBox(width: 9),
                                            Text(
                                              uploadingImages
                                                  ? '正在上传'
                                                  : review
                                                            .uploadedImages
                                                            .length >=
                                                        4
                                                  ? '更换商家图片'
                                                  : '上传商家图片',
                                            ),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'remove',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.remove_circle_outline,
                                            color: AppColors.danger,
                                            size: 20,
                                          ),
                                          SizedBox(width: 9),
                                          Text('移除收录'),
                                        ],
                                      ),
                                    ),
                                  ],
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
          if (review.uploadedImages.isNotEmpty)
            _MerchantUploadedImageCarousel(
              key: ValueKey('merchant_review_gallery_${merchant.id}'),
              images: review.uploadedImages,
              imageProviderBuilder: merchantImageProviderBuilder,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox.square(
        dimension: 92,
        child: MerchantImageView(merchant: merchant),
      ),
    );
  }
}

class _MerchantUploadedImageCarousel extends StatefulWidget {
  const _MerchantUploadedImageCarousel({
    super.key,
    required this.images,
    this.imageProviderBuilder,
  });

  final List<MerchantReviewImage> images;
  final ImageProvider Function(MerchantReviewImage image)? imageProviderBuilder;

  @override
  State<_MerchantUploadedImageCarousel> createState() =>
      _MerchantUploadedImageCarouselState();
}

class _MerchantUploadedImageCarouselState
    extends State<_MerchantUploadedImageCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _MerchantUploadedImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images.length != widget.images.length) {
      _page = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.images.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_page + 1) % widget.images.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
    });
  }

  ImageProvider<Object> _provider(MerchantReviewImage image) {
    final builder = widget.imageProviderBuilder;
    if (builder != null) return builder(image);
    return AppImageCache.provider(
      GlobalUtil().getImageURL(image.ownerId, image.imageName),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          SizedBox(
            height: 178,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final image = widget.images[index];
                final provider = _provider(image);
                final heroTag =
                    'merchant-review-${image.ownerId}-${image.imageName}';
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    key: ValueKey('merchant_review_gallery_image_$index'),
                    onTap: () => showFullscreenImage(
                      context,
                      imageProvider: provider,
                      heroTag: heroTag,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Hero(
                        tag: heroTag,
                        child: Image(
                          image: provider,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFFE8EDF0),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xFF98A0A6),
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.images.length > 1) ...[
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _page ? 16 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? AppColors.primary
                        : context.appDivider,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ],
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
