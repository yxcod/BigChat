import 'dart:io';

import 'package:path_provider/path_provider.dart';

const int maxVideoBytes = 300 * 1024 * 1024;

bool isVideoPath(String path) {
  final uri = Uri.tryParse(path);
  final clean = (uri?.queryParameters['videoName'] ?? uri?.path ?? path)
      .toLowerCase();
  return clean.endsWith('.mp4') ||
      clean.endsWith('.mov') ||
      clean.endsWith('.m4v');
}

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

Future<String> videoDownloadPath(String url) async {
  final directory = await getApplicationDocumentsDirectory();
  final videoDirectory = Directory('${directory.path}/downloaded_videos');
  if (!await videoDirectory.exists())
    await videoDirectory.create(recursive: true);
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
