import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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

typedef MomentUploadProgressCallback =
    void Function(double progress, String status);

abstract class MomentMediaUploader {
  Future<List<MomentUploadedMedia>> upload({
    required String authorId,
    required List<String> localPaths,
    MomentUploadProgressCallback? onProgress,
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
    MomentUploadProgressCallback? onProgress,
  }) async {
    final uploadedMedia = <MomentUploadedMedia>[];
    void report(int index, double itemProgress, String status) {
      if (localPaths.isEmpty) return;
      onProgress?.call(
        ((index + itemProgress.clamp(0.0, 1.0)) / localPaths.length).clamp(
          0.0,
          1.0,
        ),
        status,
      );
    }

    for (var index = 0; index < localPaths.length; index++) {
      final path = localPaths[index];
      final uri = Uri.tryParse(path);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        uploadedMedia.add(MomentUploadedMedia(url: path));
        report(index, 1, '媒体已就绪');
        continue;
      }

      final file = File(path);
      if (!await file.exists()) throw Exception('动态图片不存在');
      if (isVideoPath(path)) {
        await validateVideoFile(path);
        report(index, 0.02, '正在保存视频到本地');
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        final videoName =
            '${authorId}_moment_${timestamp}_$index.${videoExtension(path)}';
        final videoUrl = _globalUtil.getVideoURL(authorId, videoName);
        final cachedVideoPath = await cacheUploadedVideo(
          file.path,
          videoUrl,
          suggestedFileName: videoName,
        );
        if (cachedVideoPath == null) throw Exception('无法保存动态视频到本地缓存');
        report(index, 0.08, '正在准备视频');
        // Start extracting the first frame in parallel. It is an optional
        // enhancement: uploading and publishing the video must never wait for
        // a problematic HEVC/HDR asset to produce a cover.
        final thumbnailFuture = VideoThumbnailCache.resolve(cachedVideoPath);
        final thumbnailName =
            '${authorId}_moment_${timestamp}_${index}_cover.jpg';
        final thumbnailUrl = _globalUtil.getImageURL(authorId, thumbnailName);
        report(index, 0.12, '正在上传视频');
        await _httpUtil.uploadVideoFile(
          videoName,
          cachedVideoPath,
          userName: authorId,
          onSendProgress: (sent, total) {
            if (total <= 0) return;
            report(
              index,
              0.12 + (sent / total).clamp(0.0, 1.0) * 0.76,
              '正在上传视频',
            );
          },
        );
        String? uploadedThumbnailUrl;
        String? localThumbnailPath;
        final thumbnailPath = await thumbnailFuture.timeout(
          const Duration(seconds: 1),
          onTimeout: () => null,
        );
        if (thumbnailPath != null) {
          try {
            report(index, 0.9, '正在上传视频封面');
            await _httpUtil.uploadImageFile(
              thumbnailName,
              thumbnailPath,
              userName: authorId,
              options: Options(
                sendTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
              onSendProgress: (sent, total) {
                if (total <= 0) return;
                report(
                  index,
                  0.9 + (sent / total).clamp(0.0, 1.0) * 0.09,
                  '正在上传视频封面',
                );
              },
            );
            await AppImageCache.cacheUploadedFile(thumbnailUrl, thumbnailPath);
            uploadedThumbnailUrl = thumbnailUrl;
            localThumbnailPath = thumbnailPath;
          } catch (error) {
            // The video is already safely uploaded. A cover failure must not
            // discard it or leave the composer spinning indefinitely.
            debugPrint('Moment video cover upload skipped: $error');
          }
        }
        uploadedMedia.add(
          MomentUploadedMedia(
            url: videoUrl,
            thumbnailUrl: uploadedThumbnailUrl,
            localPath: cachedVideoPath,
            localThumbnailPath: localThumbnailPath,
          ),
        );
        report(index, 1, '视频上传完成');
        continue;
      }
      if (await file.length() > 5 * 1024 * 1024) {
        throw Exception('第${index + 1}张图片压缩后仍超过5MB');
      }
      final extension = await supportedImageExtension(file.path);

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final imageName = '${authorId}_moment_${timestamp}_$index.$extension';
      await _httpUtil.uploadImageFile(
        imageName,
        file.path,
        userName: authorId,
        onSendProgress: (sent, total) {
          if (total <= 0) return;
          report(index, (sent / total).clamp(0.0, 1.0), '正在上传图片');
        },
      );
      final imageUrl = _globalUtil.getImageURL(authorId, imageName);
      await AppImageCache.cacheUploadedFile(imageUrl, file.path);
      uploadedMedia.add(
        MomentUploadedMedia(url: imageUrl, localPath: file.path),
      );
      report(index, 1, '图片上传完成');
    }
    return uploadedMedia;
  }
}
