import 'package:dio/dio.dart';

import '../../../utils/gloabl.dart';
import '../../../utils/http.dart';
import '../domain/group_resource.dart';
import 'group_resource_cache.dart';
import 'group_resource_media_cache.dart';

class GroupResourceRepository {
  GroupResourceRepository({
    HttpUtil? httpUtil,
    GroupResourceCache? cache,
    GroupResourceMediaCache? mediaCache,
  }) : _http = httpUtil ?? HttpUtil(),
       _cache = cache ?? GroupResourceCache(),
       _mediaCache = mediaCache ?? const GroupResourceMediaCache();
  final HttpUtil _http;
  final GroupResourceCache _cache;
  final GroupResourceMediaCache _mediaCache;

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
    if (data is! Map || data['code'] != 100) {
      throw Exception(data is Map ? data['message'] : '获取群资源失败');
    }
    final cachedById = {
      for (final item in _cache.load(_userName, groupId, type)) item.id: item,
    };
    final items = data['items'];
    final List<GroupResource> resources = items is List
        ? items.whereType<Map>().map((item) {
            final resource = GroupResource.fromJson(
              Map<String, dynamic>.from(item),
            );
            final localPath = _mediaCache.existingPath(
              cachedById[resource.id]?.localPath,
            );
            final coverLocalPath = _mediaCache.existingPath(
              cachedById[resource.id]?.coverLocalPath,
            );
            return resource.copyWith(
              localPath: localPath,
              coverLocalPath: coverLocalPath,
            );
          }).toList()
        : const <GroupResource>[];
    try {
      await _cache.save(_userName, groupId, type, resources);
    } catch (_) {
      // A cache write must never turn a successful server response into an
      // error or replace the currently visible list.
    }
    return resources;
  }

  List<GroupResource> loadCached(int groupId, GroupResourceType type) =>
      _cache.load(_userName, groupId, type);

  Future<GroupResource> upload({
    required int groupId,
    required GroupResourceType type,
    required String path,
    required String originalName,
    String? coverPath,
    ProgressCallback? onProgress,
  }) async {
    Future<Response<dynamic>> send({required bool includeCover}) async {
      final files = <MultipartFile>[
        await MultipartFile.fromFile(path, filename: originalName),
      ];
      if (includeCover && coverPath != null && coverPath.isNotEmpty) {
        files.add(
          await MultipartFile.fromFile(
            coverPath,
            filename:
                '${originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}.cover.jpg',
            contentType: DioMediaType('image', 'jpeg'),
          ),
        );
      }
      return _http.upload(
        '/api/group/resource/upload',
        files,
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
    }

    late final Response<dynamic> response;
    try {
      response = await send(includeCover: true);
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (coverPath == null || (status != 400 && status != 415)) rethrow;
      onProgress?.call(0, 1);
      response = await send(includeCover: false);
    }
    final data = response.data;
    if (data is! Map || data['code'] != 100) {
      throw Exception(data is Map ? data['message'] : '上传失败');
    }
    final uploaded = data['data'];
    if (uploaded is! Map) throw Exception('服务器未返回上传资源信息');
    var resource = GroupResource.fromJson(Map<String, dynamic>.from(uploaded));
    if (resource.id <= 0) throw Exception('服务器未返回有效资源ID');

    final localPath = await _mediaCache.persistUpload(
      resource: resource,
      sourcePath: path,
      remoteUrl: downloadUrl(resource.id),
    );
    final visibleLocalPath = localPath ?? _mediaCache.existingPath(path);
    if (visibleLocalPath != null) {
      resource = resource.copyWith(localPath: visibleLocalPath);
    }
    if (coverPath != null && coverPath.isNotEmpty) {
      final coverLocalPath = await _mediaCache.persistCover(
        resource: resource,
        sourcePath: coverPath,
        remoteUrl: coverUrl(resource.id),
      );
      if (coverLocalPath != null) {
        resource = resource.copyWith(coverLocalPath: coverLocalPath);
      }
    }
    try {
      final existing = _cache.load(_userName, groupId, type);
      await _cache.save(_userName, groupId, type, [
        resource,
        ...existing.where((item) => item.id != resource.id),
      ]);
    } catch (_) {
      // Upload success is authoritative even when the local snapshot cannot
      // be updated. The current page still retains its optimistic preview.
    }
    return resource;
  }

  Future<void> delete(int resourceId) async {
    final response = await _http.post(
      '/api/group/resource/delete',
      data: {'resourceId': resourceId, 'userName': _userName},
    );
    final data = response.data;
    if (data is! Map || data['code'] != 100) {
      throw Exception(data is Map ? data['message'] : '删除失败');
    }
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

  String coverUrl(int resourceId) {
    final base = Uri.parse(GlobalUtil().baseURL);
    return base
        .replace(
          path: '${base.path}/api/group/resource/cover',
          queryParameters: {'resourceId': '$resourceId', 'userName': _userName},
        )
        .toString();
  }
}
