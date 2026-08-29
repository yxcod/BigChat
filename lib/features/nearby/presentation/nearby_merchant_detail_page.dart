import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../core/cache/app_image_cache.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../utils/gloabl.dart';
import '../data/baidu_poi_search_client.dart';
import '../domain/merchant_review.dart';
import '../domain/nearby_merchant.dart';
import 'merchant_category_placeholder.dart';

typedef NearbyMerchantDetailLoader =
    Future<NearbyMerchant> Function(NearbyMerchant merchant);

class NearbyMerchantDetailPage extends StatefulWidget {
  const NearbyMerchantDetailPage({
    super.key,
    required this.merchant,
    this.loader,
    this.uploadedImages = const <MerchantReviewImage>[],
    this.uploadedImageProviderBuilder,
  });

  final NearbyMerchant merchant;
  final NearbyMerchantDetailLoader? loader;
  final List<MerchantReviewImage> uploadedImages;
  final ImageProvider Function(MerchantReviewImage image)?
  uploadedImageProviderBuilder;

  @override
  State<NearbyMerchantDetailPage> createState() =>
      _NearbyMerchantDetailPageState();
}

class _NearbyMerchantDetailPageState extends State<NearbyMerchantDetailPage> {
  late NearbyMerchant _merchant;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _merchant = widget.merchant;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await (widget.loader ?? BaiduPoiSearchClient().loadDetail)(
        widget.merchant,
      );
      if (!mounted) return;
      setState(() {
        _merchant = detail;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String label, String value) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$label已复制'),
          duration: const Duration(seconds: 1),
        ),
      );
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
        title: const Text(
          '商家详情',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.appDivider),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 12),
              _buildContactCard(),
              const SizedBox(height: 12),
              _buildBusinessCard(),
            ],
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
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MerchantGallery(
            merchant: _merchant,
            uploadedImages: widget.uploadedImages,
            uploadedImageProviderBuilder: widget.uploadedImageProviderBuilder,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  key: const ValueKey('nearby_detail_merchant_name'),
                  onTap: () => _copy('商家名称', _merchant.name),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _merchant.name,
                            style: TextStyle(
                              color: context.appTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.content_copy_rounded,
                          size: 17,
                          color: context.appTextSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_merchant.rating != null)
                      _InfoChip(
                        icon: Icons.star_rounded,
                        label: '${_merchant.rating!.toStringAsFixed(1)}分',
                        color: const Color(0xFFE79B26),
                      ),
                    if (_merchant.distanceMeters != null)
                      _InfoChip(
                        icon: Icons.near_me_outlined,
                        label: _formatDistance(_merchant.distanceMeters!),
                        color: AppColors.primary,
                      ),
                    if (_merchant.price != null && _merchant.price! > 0)
                      _InfoChip(
                        icon: Icons.payments_outlined,
                        label: '¥${_formatPrice(_merchant.price!)} / 人',
                        color: const Color(0xFFE56F55),
                      ),
                  ],
                ),
                if (_merchant.category.isNotEmpty) ...[
                  const SizedBox(height: 11),
                  Text(
                    _merchant.category,
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _DetailActionRow(
            key: const ValueKey('nearby_detail_address'),
            icon: Icons.location_on_outlined,
            title: '位置信息',
            value: _merchant.address.isEmpty ? '暂无详细地址' : _merchant.address,
            enabled: _merchant.address.isNotEmpty,
            onTap: () => _copy('地点', _merchant.address),
          ),
          Divider(
            height: 1,
            indent: 56,
            endIndent: 14,
            color: context.appDivider,
          ),
          _DetailActionRow(
            key: const ValueKey('nearby_detail_phone'),
            icon: Icons.phone_outlined,
            title: '联系电话',
            value: _merchant.phone.isEmpty ? '暂无电话' : _merchant.phone,
            enabled: _merchant.phone.isNotEmpty,
            onTap: () => _copy('电话', _merchant.phone),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _BusinessInfoRow(
            label: '营业时间',
            value: _merchant.openingHours.isEmpty
                ? '商家暂未提供'
                : _merchant.openingHours,
          ),
          if (_merchant.latitude != null && _merchant.longitude != null) ...[
            Divider(height: 1, color: context.appDivider),
            _BusinessInfoRow(
              label: '地图坐标',
              value:
                  '${_merchant.latitude!.toStringAsFixed(6)}, ${_merchant.longitude!.toStringAsFixed(6)}',
            ),
          ],
        ],
      ),
    );
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _MerchantGallery extends StatefulWidget {
  const _MerchantGallery({
    required this.merchant,
    required this.uploadedImages,
    this.uploadedImageProviderBuilder,
  });

  final NearbyMerchant merchant;
  final List<MerchantReviewImage> uploadedImages;
  final ImageProvider Function(MerchantReviewImage image)?
  uploadedImageProviderBuilder;

  @override
  State<_MerchantGallery> createState() => _MerchantGalleryState();
}

class _MerchantGalleryState extends State<_MerchantGallery> {
  late final PageController _pageController;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant _MerchantGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uploadedImages.length != widget.uploadedImages.length) {
      _page = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.uploadedImages.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_page + 1) % widget.uploadedImages.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOut,
      );
    });
  }

  ImageProvider<Object> _uploadedImageProvider(MerchantReviewImage image) {
    final builder = widget.uploadedImageProviderBuilder;
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
    if (widget.uploadedImages.isNotEmpty) {
      return SizedBox(
        key: const ValueKey('nearby_detail_uploaded_gallery'),
        height: 210,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.uploadedImages.length,
              onPageChanged: (value) => setState(() => _page = value),
              itemBuilder: (context, index) {
                final image = widget.uploadedImages[index];
                final provider = _uploadedImageProvider(image);
                final heroTag =
                    'merchant-detail-${image.ownerId}-${image.imageName}';
                return GestureDetector(
                  key: ValueKey('nearby_detail_uploaded_image_$index'),
                  onTap: () => showFullscreenImage(
                    context,
                    imageProvider: provider,
                    heroTag: heroTag,
                  ),
                  child: Hero(
                    tag: heroTag,
                    child: Image(
                      image: provider,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => MerchantCategoryPlaceholder(
                        merchant: widget.merchant,
                        showLabel: true,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (widget.uploadedImages.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.uploadedImages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == _page ? 15 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index == _page
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final images = widget.merchant.availableImageUrls;
    if (images.isEmpty) {
      return SizedBox(
        height: 190,
        width: double.infinity,
        child: MerchantCategoryPlaceholder(
          merchant: widget.merchant,
          showLabel: true,
          caption: widget.merchant.imageCount > 0
              ? '商家图片暂不可读取'
              : merchantCategoryVisual(widget.merchant).label,
        ),
      );
    }
    return SizedBox(
      height: 210,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) => MerchantImageView(
          merchant: widget.merchant,
          imageUrl: images[index],
          showFallbackLabel: true,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailActionRow extends StatelessWidget {
  const _DetailActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 23),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: enabled
                            ? context.appTextSecondary
                            : context.appTextSecondary.withValues(alpha: 0.65),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                const Icon(
                  Icons.content_copy_rounded,
                  size: 18,
                  color: Color(0xFFA3A6AB),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessInfoRow extends StatelessWidget {
  const _BusinessInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(color: context.appTextSecondary, fontSize: 13.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
