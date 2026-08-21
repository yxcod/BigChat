import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

class AppImageCache {
  const AppImageCache._();

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
    return CachedNetworkImageProvider(imageUrl, cacheKey: cacheKey(imageUrl));
  }
}
