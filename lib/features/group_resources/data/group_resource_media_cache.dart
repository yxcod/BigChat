import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/cache/app_image_cache.dart';
import '../../../core/media/video_media.dart';
import '../../../core/media/video_thumbnail_cache.dart';
import '../domain/group_resource.dart';

class GroupResourceMediaCache {
  const GroupResourceMediaCache();

  String? existingPath(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 0 ? path : null;
  }

  Future<String?> persistUpload({
    required GroupResource resource,
    required String sourcePath,
    required String remoteUrl,
  }) async {
    if (resource.isImage) {
      try {
        final source = File(sourcePath);
        if (!await source.exists() || await source.length() <= 0) return null;
        final root = await getApplicationSupportDirectory();
        final directory = Directory('${root.path}/group_resource_image_cache');
        await directory.create(recursive: true);
        final extension = _safeExtension(resource.originalName, 'jpg');
        final destination = File(
          '${directory.path}/resource_${resource.id}.$extension',
        );
        final temporary = File('${destination.path}.part');
        if (await temporary.exists()) await temporary.delete();
        await source.copy(temporary.path);
        if (await destination.exists()) await destination.delete();
        await temporary.rename(destination.path);
        // Also seed normal image widgets. Failure here does not invalidate the
        // dedicated non-evicting uploaded-media copy above.
        await AppImageCache.cacheUploadedFile(remoteUrl, destination.path);
        return destination.path;
      } catch (_) {
        return null;
      }
    }
    if (!resource.isVideo) return null;
    final cached = await cacheUploadedVideo(
      sourcePath,
      remoteUrl,
      suggestedFileName: resource.originalName,
    );
    if (cached != null) {
      // Warm the first-frame cache before replacing the optimistic local tile.
      await VideoThumbnailCache.resolve(cached);
    }
    return cached;
  }

  Future<String?> persistCover({
    required GroupResource resource,
    required String sourcePath,
    required String remoteUrl,
  }) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists() || await source.length() <= 0) return null;
      final root = await getApplicationSupportDirectory();
      final directory = Directory('${root.path}/group_resource_cover_cache');
      await directory.create(recursive: true);
      final destination = File('${directory.path}/resource_${resource.id}.jpg');
      final temporary = File('${destination.path}.part');
      if (await temporary.exists()) await temporary.delete();
      await source.copy(temporary.path);
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destination.path);
      await AppImageCache.cacheUploadedFile(remoteUrl, destination.path);
      return destination.path;
    } catch (_) {
      return null;
    }
  }

  String _safeExtension(String value, String fallback) {
    final index = value.lastIndexOf('.');
    if (index < 0 || index == value.length - 1) return fallback;
    final extension = value.substring(index + 1).toLowerCase();
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(extension)
        ? extension
        : fallback;
  }
}
