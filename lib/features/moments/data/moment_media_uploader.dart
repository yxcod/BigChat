import 'dart:io';

import '../../../utils/gloabl.dart';
import '../../../utils/http.dart';
import '../../../core/media/video_media.dart';
import '../../../core/media/video_thumbnail_cache.dart';
import '../../../core/cache/app_image_cache.dart';
import '../../../core/media/image_file_format.dart';

class MomentUploadedMedia {
  const MomentUploadedMedia({
    required this.url,
    this.thumbnailUrl,
    this.localPath,
    this.localThumbnailPath,
  });

  final String url;
  final String? thumbnailUrl;
  final String? localPath;
  final String? localThumbnailPath;
}

abstract class MomentMediaUploader {
  Future<List<MomentUploadedMedia>> upload({
    required String authorId,
    required List<String> localPaths,
  });
}

class ServerMomentMediaUploader implements MomentMediaUploader {
  ServerMomentMediaUploader({HttpUtil? httpUtil, GlobalUtil? globalUtil})
    : _httpUtil = httpUtil ?? HttpUtil(),
      _globalUtil = globalUtil ?? GlobalUtil();

  final HttpUtil _httpUtil;
  final GlobalUtil _globalUtil;

  @override
  Future<List<MomentUploadedMedia>> upload({
    required String authorId,
    required List<String> localPaths,
  }) async {
    final uploadedMedia = <MomentUploadedMedia>[];
    for (var index = 0; index < localPaths.length; index++) {
      final path = localPaths[index];
      final uri = Uri.tryParse(path);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        uploadedMedia.add(MomentUploadedMedia(url: path));
        continue;
      }

      final file = File(path);
      if (!await file.exists()) throw Exception('动态图片不存在');
      if (isVideoPath(path)) {
        await validateVideoFile(path);
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        final videoName =
            '${authorId}_moment_${timestamp}_$index.${videoExtension(path)}';
        final thumbnailPath = await VideoThumbnailCache.resolve(file.path);
        if (thumbnailPath == null) throw Exception('无法生成动态视频封面');
        final thumbnailName =
            '${authorId}_moment_${timestamp}_${index}_cover.jpg';
        final videoUrl = _globalUtil.getVideoURL(authorId, videoName);
        final thumbnailUrl = _globalUtil.getImageURL(authorId, thumbnailName);
        final cachedVideoPath = await cacheUploadedVideo(
          file.path,
          videoUrl,
          suggestedFileName: videoName,
        );
        if (cachedVideoPath == null) throw Exception('无法保存动态视频到本地缓存');
        await _httpUtil.uploadImageFile(
          thumbnailName,
          thumbnailPath,
          userName: authorId,
        );
        await _httpUtil.uploadVideoFile(
          videoName,
          cachedVideoPath,
          userName: authorId,
        );
        await AppImageCache.cacheUploadedFile(thumbnailUrl, thumbnailPath);
        uploadedMedia.add(
          MomentUploadedMedia(
            url: videoUrl,
            thumbnailUrl: thumbnailUrl,
            localPath: cachedVideoPath,
            localThumbnailPath: thumbnailPath,
          ),
        );
        continue;
      }
      if (await file.length() > 5 * 1024 * 1024) {
        throw Exception('第${index + 1}张图片压缩后仍超过5MB');
      }
      final extension = await supportedImageExtension(file.path);

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final imageName = '${authorId}_moment_${timestamp}_$index.$extension';
      await _httpUtil.uploadImageFile(imageName, file.path, userName: authorId);
      final imageUrl = _globalUtil.getImageURL(authorId, imageName);
      await AppImageCache.cacheUploadedFile(imageUrl, file.path);
      uploadedMedia.add(
        MomentUploadedMedia(url: imageUrl, localPath: file.path),
      );
    }
    return uploadedMedia;
  }
}
