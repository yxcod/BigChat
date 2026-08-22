import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppImageCache {
  const AppImageCache._();

  static final CacheManager manager = CacheManager(
    Config(
      'big-chat-images-v2',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 800,
    ),
  );

  /// Uses the server-side image identity instead of the authenticated URL.
  /// A renewed token therefore keeps hitting disk cache, while a changed
  /// imageName automatically creates a new cache entry.
  static String cacheKey(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) return imageUrl;

    final ownerId = uri.queryParameters['userName'];
    final imageName = uri.queryParameters['imageName'];
    if (ownerId == null ||
        ownerId.isEmpty ||
        imageName == null ||
        imageName.isEmpty) {
      return imageUrl;
    }
    return 'server-image:${Uri.encodeComponent(ownerId)}:'
        '${Uri.encodeComponent(imageName)}';
  }

  static ImageProvider<Object> provider(String imageUrl) {
    return CachedNetworkImageProvider(
      imageUrl,
      cacheKey: cacheKey(imageUrl),
      cacheManager: manager,
    );
  }

  static Future<void> clear() => manager.emptyCache();
}
