import 'dart:io';

import '../../../utils/gloabl.dart';
import '../../../utils/http.dart';
import '../../../core/media/video_media.dart';
import '../../../core/media/image_file_format.dart';

abstract class MomentMediaUploader {
  Future<List<String>> upload({
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
  Future<List<String>> upload({
    required String authorId,
    required List<String> localPaths,
  }) async {
    final uploadedUrls = <String>[];
    for (var index = 0; index < localPaths.length; index++) {
      final path = localPaths[index];
      final uri = Uri.tryParse(path);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        uploadedUrls.add(path);
        continue;
      }

      final file = File(path);
      if (!await file.exists()) throw Exception('动态图片不存在');
      if (isVideoPath(path)) {
        await validateVideoFile(path);
        final timestamp = DateTime.now().microsecondsSinceEpoch;
        final videoName =
            '${authorId}_moment_${timestamp}_$index.${videoExtension(path)}';
        await _httpUtil.uploadVideoFile(
          videoName,
          file.path,
          userName: authorId,
        );
        uploadedUrls.add(_globalUtil.getVideoURL(authorId, videoName));
        continue;
      }
      if (await file.length() > 5 * 1024 * 1024) {
        throw Exception('第${index + 1}张图片压缩后仍超过5MB');
      }
      final extension = await supportedImageExtension(file.path);

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final imageName = '${authorId}_moment_${timestamp}_$index.$extension';
      await _httpUtil.uploadImageFile(imageName, file.path, userName: authorId);
      uploadedUrls.add(_globalUtil.getImageURL(authorId, imageName));
    }
    return uploadedUrls;
  }
}
