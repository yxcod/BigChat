import 'dart:io';

import '../../../utils/gloabl.dart';
import '../../../utils/http.dart';

abstract class SpaceCoverUploader {
  Future<String> upload({
    required String ownerUserName,
    required String localPath,
  });
}

class ServerSpaceCoverUploader implements SpaceCoverUploader {
  ServerSpaceCoverUploader({HttpUtil? httpUtil, GlobalUtil? globalUtil})
    : _httpUtil = httpUtil ?? HttpUtil(),
      _globalUtil = globalUtil ?? GlobalUtil();

  final HttpUtil _httpUtil;
  final GlobalUtil _globalUtil;

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
    final extension = _extension(localPath);
    final name =
        '${ownerUserName}_space_cover_${DateTime.now().microsecondsSinceEpoch}.$extension';
    final success = await _httpUtil.uploadImageFile(
      name,
      localPath,
      userName: ownerUserName,
    );
    if (!success) throw Exception('封面上传失败');
    return _globalUtil.getImageURL(ownerUserName, name);
  }

  String _extension(String path) {
    final value = path.split('.').last.toLowerCase();
    if (value == 'jpeg') return 'jpg';
    if (value == 'png' || value == 'webp' || value == 'jpg') return value;
    return 'jpg';
  }
}
