import 'dart:io';

import '../../../utils/http.dart';
import '../../../core/media/image_file_format.dart';

abstract class SpaceCoverUploader {
  Future<String> upload({
    required String ownerUserName,
    required String localPath,
  });
}

class ServerSpaceCoverUploader implements SpaceCoverUploader {
  ServerSpaceCoverUploader({HttpUtil? httpUtil})
    : _httpUtil = httpUtil ?? HttpUtil();

  final HttpUtil _httpUtil;

  @override
  Future<String> upload({
    required String ownerUserName,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) throw Exception('封面图片不存在');
    if (await file.length() > 5 * 1024 * 1024) {
      throw Exception('封面图片不能超过5MB');
    }
    final extension = await supportedImageExtension(localPath);
    final name =
        '${ownerUserName}_space_cover_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final success = await _httpUtil.uploadImageFile(
      name,
      localPath,
      userName: ownerUserName,
    );
    if (!success) throw Exception('封面上传失败');
    // Persist a stable resource identity. Download URLs contain a login token
    // and must be regenerated whenever the space is opened again.
    return name;
  }
}
