import 'package:flutter/material.dart';

import '../domain/nearby_merchant.dart';

class MerchantCategoryVisual {
  const MerchantCategoryVisual({
    required this.icon,
    required this.label,
    required this.beginColor,
    required this.endColor,
  });

  final IconData icon;
  final String label;
  final Color beginColor;
  final Color endColor;
}

MerchantCategoryVisual merchantCategoryVisual(NearbyMerchant merchant) {
  final text = '${merchant.category} ${merchant.name}'.toLowerCase();
  bool containsAny(Iterable<String> keywords) =>
      keywords.any((keyword) => text.contains(keyword.toLowerCase()));

  if (containsAny(['棋牌', '麻将', '扑克', '桌游'])) {
    return const MerchantCategoryVisual(
      icon: Icons.style_rounded,
      label: '棋牌娱乐',
      beginColor: Color(0xFF7048B6),
      endColor: Color(0xFFA978D4),
    );
  }
  if (containsAny(['咖啡', '茶馆', '茶饮', '奶茶'])) {
    return const MerchantCategoryVisual(
      icon: Icons.local_cafe_rounded,
      label: '咖啡茶饮',
      beginColor: Color(0xFF9A6A4B),
      endColor: Color(0xFFD39A70),
    );
  }
  if (containsAny(['美食', '餐饮', '饭店', '餐厅', '火锅', '烧烤', '小吃', '面馆', '菜馆'])) {
    return const MerchantCategoryVisual(
      icon: Icons.restaurant_rounded,
      label: '餐饮美食',
      beginColor: Color(0xFFE67945),
      endColor: Color(0xFFF5AC69),
    );
  }
  if (containsAny(['酒店', '宾馆', '民宿', '旅馆'])) {
    return const MerchantCategoryVisual(
      icon: Icons.hotel_rounded,
      label: '酒店住宿',
      beginColor: Color(0xFF5875D7),
      endColor: Color(0xFF8CA6EF),
    );
  }
  if (containsAny(['ktv', '酒吧', '音乐', '歌厅'])) {
    return const MerchantCategoryVisual(
      icon: Icons.mic_rounded,
      label: '音乐娱乐',
      beginColor: Color(0xFF7A55C7),
      endColor: Color(0xFFBE72D0),
    );
  }
  if (containsAny(['影院', '电影', '剧院', '演出'])) {
    return const MerchantCategoryVisual(
      icon: Icons.local_movies_rounded,
      label: '电影演出',
      beginColor: Color(0xFF3E506F),
      endColor: Color(0xFF7286A8),
    );
  }
  if (containsAny(['景点', '公园', '旅游', '博物馆', '展览', '古迹'])) {
    return const MerchantCategoryVisual(
      icon: Icons.landscape_rounded,
      label: '景点游览',
      beginColor: Color(0xFF3E9A78),
      endColor: Color(0xFF70C39B),
    );
  }
  if (containsAny(['购物', '商场', '超市', '便利店', '百货'])) {
    return const MerchantCategoryVisual(
      icon: Icons.shopping_bag_rounded,
      label: '商场购物',
      beginColor: Color(0xFFD45E8C),
      endColor: Color(0xFFEC96B5),
    );
  }
  if (containsAny(['医院', '诊所', '药店', '口腔', '体检'])) {
    return const MerchantCategoryVisual(
      icon: Icons.local_hospital_rounded,
      label: '医疗健康',
      beginColor: Color(0xFF3F9FB1),
      endColor: Color(0xFF75C9CE),
    );
  }
  if (containsAny(['健身', '体育', '球馆', '运动', '游泳'])) {
    return const MerchantCategoryVisual(
      icon: Icons.sports_basketball_rounded,
      label: '运动健身',
      beginColor: Color(0xFFE28A39),
      endColor: Color(0xFFF2BD66),
    );
  }
  if (containsAny(['美容', '美发', 'spa', '按摩', '足浴'])) {
    return const MerchantCategoryVisual(
      icon: Icons.spa_rounded,
      label: '丽人休闲',
      beginColor: Color(0xFFC95F9F),
      endColor: Color(0xFFE99AC5),
    );
  }
  if (containsAny(['学校', '教育', '培训', '书店'])) {
    return const MerchantCategoryVisual(
      icon: Icons.school_rounded,
      label: '教育文化',
      beginColor: Color(0xFF4B86C4),
      endColor: Color(0xFF78AFDE),
    );
  }
  if (containsAny(['汽车', '加油', '停车', '维修'])) {
    return const MerchantCategoryVisual(
      icon: Icons.directions_car_rounded,
      label: '汽车服务',
      beginColor: Color(0xFF4F6C85),
      endColor: Color(0xFF8199AB),
    );
  }
  if (containsAny(['娱乐', '游乐', '电玩', '网吧'])) {
    return const MerchantCategoryVisual(
      icon: Icons.sports_esports_rounded,
      label: '休闲娱乐',
      beginColor: Color(0xFF6558B8),
      endColor: Color(0xFF9488DE),
    );
  }
  return const MerchantCategoryVisual(
    icon: Icons.storefront_rounded,
    label: '附近商家',
    beginColor: Color(0xFF419F79),
    endColor: Color(0xFF76C6A1),
  );
}

class MerchantCategoryPlaceholder extends StatelessWidget {
  const MerchantCategoryPlaceholder({
    super.key,
    required this.merchant,
    this.showLabel = false,
    this.caption,
  });

  final NearbyMerchant merchant;
  final bool showLabel;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final visual = merchantCategoryVisual(merchant);
    return Container(
      key: ValueKey('merchant-placeholder-${visual.label}'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [visual.beginColor, visual.endColor],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(right: -18, top: -22, child: _DecorativeCircle(size: 72)),
          Positioned(
            left: -12,
            bottom: -20,
            child: _DecorativeCircle(size: 58),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  visual.icon,
                  color: Colors.white,
                  size: showLabel ? 50 : 36,
                ),
                if (showLabel) ...[
                  const SizedBox(height: 9),
                  Text(
                    caption ?? visual.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0x1FFFFFFF),
    ),
  );
}
