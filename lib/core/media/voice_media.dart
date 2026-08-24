import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> voiceCachePath(String url, {Directory? rootDirectory}) async {
  final directory = rootDirectory ?? await getApplicationSupportDirectory();
  final voiceDirectory = Directory('${directory.path}/chat_voice_cache');
  if (!await voiceDirectory.exists()) {
    await voiceDirectory.create(recursive: true);
  }
  final uri = Uri.parse(url);
  final owner = uri.queryParameters['userName'] ?? 'unknown';
  final requestedName = uri.queryParameters['audioName'];
  final fallback = uri.pathSegments.isEmpty
      ? 'voice.m4a'
      : uri.pathSegments.last;
  final safeName = '${owner}_${requestedName ?? fallback}'.replaceAll(
    RegExp(r'[^A-Za-z0-9._-]'),
    '_',
  );
  return '${voiceDirectory.path}/$safeName';
}

Future<String?> cachedVoicePath(String url, {Directory? rootDirectory}) async {
  final path = await voiceCachePath(url, rootDirectory: rootDirectory);
  final file = File(path);
  if (!await file.exists() || await file.length() <= 0) return null;
  return path;
}

Future<String?> cacheUploadedVoice(
  String localPath,
  String remoteUrl, {
  Directory? rootDirectory,
}) async {
  try {
    final source = File(localPath);
    if (!await source.exists() || await source.length() <= 0) return null;
    final destinationPath = await voiceCachePath(
      remoteUrl,
      rootDirectory: rootDirectory,
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
