import 'dart:io';

import '../../../utils/http.dart';
import '../../../core/media/image_file_format.dart';

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
    if (!await file.exists()) throw Exception('点评图片不存在');
    if (await file.length() > 5 * 1024 * 1024) {
      throw Exception('点评图片不能超过5MB');
    }
    final extension = await supportedImageExtension(file.path);
    final imageName =
        '${authorId}_merchant_review_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final uploaded = await _httpUtil.uploadImageFile(
      imageName,
      localPath,
      userName: authorId,
    );
    if (!uploaded) throw Exception('服务器未接收图片');
    return imageName;
  }
}
