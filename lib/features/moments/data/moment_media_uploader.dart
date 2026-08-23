import 'dart:io';

import '../../../utils/gloabl.dart';
import '../../../utils/http.dart';
import '../../../core/media/video_media.dart';

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
      final extension = await _detectExtension(file);
      if (extension == null) {
        throw Exception('第${index + 1}张图片格式不受支持，请选择JPEG、PNG或WebP');
      }

      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final imageName = '${authorId}_moment_${timestamp}_$index.$extension';
      await _httpUtil.uploadImageFile(imageName, file.path, userName: authorId);
      uploadedUrls.add(_globalUtil.getImageURL(authorId, imageName));
    }
    return uploadedUrls;
  }

  Future<String?> _detectExtension(File file) async {
    final reader = await file.open();
    try {
      final header = await reader.read(12);
      if (header.length >= 3 &&
          header[0] == 0xff &&
          header[1] == 0xd8 &&
          header[2] == 0xff) {
        return 'jpg';
      }
      const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
      if (_startsWith(header, png)) {
        return 'png';
      }
      if (header.length >= 12 &&
          String.fromCharCodes(header.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(header.sublist(8, 12)) == 'WEBP') {
        return 'webp';
      }
      return null;
    } finally {
      await reader.close();
    }
  }

  bool _startsWith(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }
}
