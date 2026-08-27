import 'dart:io';

import '../../../utils/http.dart';

abstract class MerchantReviewImageUploader {
  Future<String> upload({required String authorId, required String localPath});
}

class ServerMerchantReviewImageUploader implements MerchantReviewImageUploader {
  ServerMerchantReviewImageUploader({HttpUtil? httpUtil})
    : _httpUtil = httpUtil ?? HttpUtil();

  final HttpUtil _httpUtil;

  @override
  Future<String> upload({
    required String authorId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) throw Exception('评论图片不存在');
    if (await file.length() > 5 * 1024 * 1024) {
      throw Exception('评论图片不能超过5MB');
    }
    final extension = await _detectExtension(file);
    if (extension == null) {
      throw Exception('评论图片格式不受支持，请选择JPEG、PNG或WebP');
    }
    final imageName =
        '${authorId}_merchant_review_${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _httpUtil.uploadImageFile(imageName, localPath, userName: authorId);
    return imageName;
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
      if (_startsWith(header, png)) return 'png';
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
