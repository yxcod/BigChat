import 'dart:io';

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
    final version = uri.queryParameters['version']?.trim() ?? '';
    return 'server-image:${Uri.encodeComponent(ownerId)}:'
        '${Uri.encodeComponent(imageName)}'
        '${version.isEmpty ? '' : ':${Uri.encodeComponent(version)}'}';
  }

  static ImageProvider<Object> provider(String imageUrl) {
    return CachedNetworkImageProvider(
      imageUrl,
      cacheKey: cacheKey(imageUrl),
      cacheManager: manager,
    );
  }

  /// Seeds the same disk cache used by network images with an uploaded local
  /// file. The uploader can therefore keep rendering the original bytes even
  /// after the UI has switched to the server resource id.
  static Future<String?> cacheUploadedFile(
    String imageUrl,
    String localPath,
  ) async {
    try {
      final source = File(localPath);
      if (!await source.exists() || await source.length() <= 0) return null;
      final extension = localPath.split('.').last.toLowerCase();
      final cached = await manager.putFile(
        imageUrl,
        await source.readAsBytes(),
        key: cacheKey(imageUrl),
        fileExtension: extension.length <= 5 ? extension : 'jpg',
      );
      return cached.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() => manager.emptyCache();
}
