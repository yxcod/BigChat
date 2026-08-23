import 'package:dio/dio.dart';

import '../../../utils/gloabl.dart';
import '../../../utils/http.dart';
import '../domain/group_resource.dart';

class GroupResourceRepository {
  GroupResourceRepository({HttpUtil? httpUtil})
    : _http = httpUtil ?? HttpUtil();
  final HttpUtil _http;

  String get _userName => GlobalUtil().userName ?? '';

  Future<List<GroupResource>> list(int groupId, GroupResourceType type) async {
    final response = await _http.get(
      '/api/group/resource/list',
      queryParameters: {
        'groupId': groupId,
        'userName': _userName,
        'resourceType': type == GroupResourceType.file ? 1 : 2,
      },
    );
    final data = response.data;
    if (data is! Map || data['code'] != 100)
      throw Exception(data is Map ? data['message'] : '获取群资源失败');
    final items = data['items'];
    return items is List
        ? items
              .whereType<Map>()
              .map(
                (item) =>
                    GroupResource.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const [];
  }

  Future<void> upload({
    required int groupId,
    required GroupResourceType type,
    required String path,
    required String originalName,
    ProgressCallback? onProgress,
  }) async {
    final file = await MultipartFile.fromFile(path, filename: originalName);
    final response = await _http.upload(
      '/api/group/resource/upload',
      [file],
      fieldName: 'file',
      queryParameters: {
        'groupId': groupId,
        'userName': _userName,
        'resourceType': type == GroupResourceType.file ? 1 : 2,
      },
      options: Options(
        sendTimeout: const Duration(minutes: 20),
        receiveTimeout: const Duration(minutes: 2),
      ),
      onSendProgress: onProgress,
    );
    final data = response.data;
    if (data is! Map || data['code'] != 100)
      throw Exception(data is Map ? data['message'] : '上传失败');
  }

  Future<void> delete(int resourceId) async {
    final response = await _http.post(
      '/api/group/resource/delete',
      data: {'resourceId': resourceId, 'userName': _userName},
    );
    final data = response.data;
    if (data is! Map || data['code'] != 100)
      throw Exception(data is Map ? data['message'] : '删除失败');
  }

  String downloadUrl(int resourceId) {
    final base = Uri.parse(GlobalUtil().baseURL);
    return base
        .replace(
          path: '${base.path}/api/group/resource/download',
          queryParameters: {'resourceId': '$resourceId', 'userName': _userName},
        )
        .toString();
  }
}
