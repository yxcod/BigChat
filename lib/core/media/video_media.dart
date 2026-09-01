import 'dart:io';

import 'package:path_provider/path_provider.dart';

const int maxVideoBytes = 300 * 1024 * 1024;

bool isVideoPath(String path) {
  final uri = Uri.tryParse(path);
  final clean =
      (uri?.queryParameters['videoName'] ??
              uri?.queryParameters['fileName'] ??
              uri?.queryParameters['resourceName'] ??
              uri?.path ??
              path)
          .toLowerCase();
  return clean.endsWith('.mp4') ||
      clean.endsWith('.mov') ||
      clean.endsWith('.m4v');
}

String videoSuggestedName(String source, {String fallback = 'video.mp4'}) {
  final uri = Uri.tryParse(source);
  final candidate =
      uri?.queryParameters['videoName'] ??
      uri?.queryParameters['fileName'] ??
      uri?.queryParameters['resourceName'] ??
      (uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : source);
  final normalized = candidate.split('/').last.split('\\').last.trim();
  if (normalized.isEmpty || !isVideoPath(normalized)) return fallback;
  return normalized.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

String videoCoverName(String source) =>
    '${videoSuggestedName(source, fallback: 'video.mp4')}.cover.jpg';

Future<void> validateVideoFile(String path) async {
  final file = File(path);
  if (!await file.exists()) throw Exception('视频文件不存在');
  final length = await file.length();
  if (length <= 0) throw Exception('视频文件为空');
  if (length > maxVideoBytes) throw Exception('单个视频不能超过300MB');
  if (!isVideoPath(path)) throw Exception('仅支持 MP4、MOV、M4V 视频');
}

String videoExtension(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mov')) return 'mov';
  if (lower.endsWith('.m4v')) return 'm4v';
  return 'mp4';
}

String videoOwnerFromName(String value, {required String fallbackOwner}) {
  final uri = Uri.tryParse(value);
  final fileName =
      uri?.queryParameters['videoName'] ??
      (uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : value);
  final separator = fileName.indexOf('_');
  if (separator <= 0) return fallbackOwner;
  final owner = fileName.substring(0, separator).trim();
  return owner.isEmpty ? fallbackOwner : owner;
}

Future<String> videoDownloadPath(String url) async {
  final directory = await getApplicationDocumentsDirectory();
  final videoDirectory = Directory('${directory.path}/downloaded_videos');
  if (!await videoDirectory.exists()) {
    await videoDirectory.create(recursive: true);
  }
  final uri = Uri.parse(url);
  final requestedName = uri.queryParameters['videoName'];
  final fallback = uri.pathSegments.isEmpty
      ? 'video.mp4'
      : uri.pathSegments.last;
  final safeName = (requestedName ?? fallback).replaceAll(
    RegExp(r'[^A-Za-z0-9._-]'),
    '_',
  );
  return '${videoDirectory.path}/$safeName';
}

Future<String> videoCachePath(
  String url, {
  Directory? rootDirectory,
  String? suggestedFileName,
}) async {
  final directory = rootDirectory ?? await getApplicationSupportDirectory();
  final videoDirectory = Directory('${directory.path}/chat_video_cache');
  if (!await videoDirectory.exists()) {
    await videoDirectory.create(recursive: true);
  }
  final uri = Uri.parse(url);
  final owner = uri.queryParameters['userName'] ?? 'unknown';
  final requestedName =
      suggestedFileName ??
      uri.queryParameters['videoName'] ??
      uri.queryParameters['fileName'] ??
      uri.queryParameters['resourceName'];
  final resourceId = uri.queryParameters['resourceId']?.trim();
  final fallback = uri.pathSegments.isEmpty
      ? 'video.mp4'
      : uri.pathSegments.last;
  final identity = resourceId?.isNotEmpty == true
      ? 'group_${resourceId!}_${requestedName ?? fallback}'
      : requestedName ?? fallback;
  var safeName = '${owner}_$identity'.replaceAll(
    RegExp(r'[^A-Za-z0-9._-]'),
    '_',
  );
  if (!isVideoPath(safeName)) safeName = '$safeName.mp4';
  return '${videoDirectory.path}/$safeName';
}

Future<String?> cachedVideoPath(
  String url, {
  Directory? rootDirectory,
  String? suggestedFileName,
}) async {
  final path = await videoCachePath(
    url,
    rootDirectory: rootDirectory,
    suggestedFileName: suggestedFileName,
  );
  final file = File(path);
  if (!await file.exists() || await file.length() <= 0) return null;
  return path;
}

Future<String?> cacheUploadedVideo(
  String localPath,
  String remoteUrl, {
  Directory? rootDirectory,
  String? suggestedFileName,
}) async {
  try {
    final source = File(localPath);
    if (!await source.exists() || await source.length() <= 0) return null;
    final destinationPath = await videoCachePath(
      remoteUrl,
      rootDirectory: rootDirectory,
      suggestedFileName: suggestedFileName,
    );
    if (source.absolute.path == File(destinationPath).absolute.path) {
      return destinationPath;
    }
    final temporary = File('$destinationPath.part');
    if (await temporary.exists()) await temporary.delete();
    await source.copy(temporary.path);
    final destination = File(destinationPath);
    if (await destination.exists()) await destination.delete();
    await temporary.rename(destinationPath);
    return destinationPath;
  } catch (_) {
    return null;
  }
}
