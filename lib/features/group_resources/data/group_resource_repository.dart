import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

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
    final hasCover = coverPath != null && coverPath.isNotEmpty;
    final mediaFile = await MultipartFile.fromFile(
      path,
      filename: originalName,
    );
    // Keep the established single-file upload contract. The video must not be
    // rolled back just because a server version cannot yet accept its cover.
    final response = await _http.upload(
      '/api/group/resource/upload',
      [mediaFile],
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
      onSendProgress: (sent, total) {
        if (!hasCover || total <= 0) {
          onProgress?.call(sent, total);
          return;
        }
        onProgress?.call((sent * 94 / 100).round(), total);
      },
    );
    final data = response.data;
    if (data is! Map || data['code'] != 100) {
      throw Exception(data is Map ? data['message'] : '上传失败');
    }
    final uploaded = data['data'];
    if (uploaded is! Map) throw Exception('服务器未返回上传资源信息');
    var resource = GroupResource.fromJson(Map<String, dynamic>.from(uploaded));
    if (resource.id <= 0) throw Exception('服务器未返回有效资源ID');

    var coverUploaded = false;
    if (hasCover) {
      try {
        final coverFile = await MultipartFile.fromFile(
          coverPath,
          filename:
              '${originalName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}.cover.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        );
        final coverResponse = await _http.upload(
          '/api/group/resource/cover/upload',
          [coverFile],
          fieldName: 'file',
          queryParameters: {'resourceId': resource.id, 'userName': _userName},
          options: Options(
            sendTimeout: const Duration(minutes: 1),
            receiveTimeout: const Duration(seconds: 30),
          ),
          onSendProgress: (sent, total) {
            if (total <= 0) return;
            final coverFraction = (sent / total).clamp(0.0, 1.0);
            onProgress?.call((94 + coverFraction * 6).round(), 100);
          },
        );
        coverUploaded =
            coverResponse.data is Map && coverResponse.data['code'] == 100;
      } catch (error) {
        // An older server has no separate-cover endpoint. The uploaded video
        // remains valid and this device still keeps its generated local cover.
        debugPrint('Group video cover upload deferred: $error');
      }
      onProgress?.call(1, 1);
    }

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
        resource = resource.copyWith(
          hasCover: resource.hasCover || coverUploaded,
          coverLocalPath: coverLocalPath,
        );
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
