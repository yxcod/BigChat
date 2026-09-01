import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class VideoThumbnailCache {
  VideoThumbnailCache._();

  static final Map<String, Future<String?>> _pending = {};

  static Future<String?> resolve(String source, {Directory? rootDirectory}) {
    final normalized = source.trim();
    if (normalized.isEmpty) return Future<String?>.value();
    return _pending.putIfAbsent(
      normalized,
      () => _generate(
        normalized,
        rootDirectory: rootDirectory,
      ).whenComplete(() => _pending.remove(normalized)),
    );
  }

  static Future<String?> _generate(
    String source, {
    Directory? rootDirectory,
  }) async {
    try {
      final root = rootDirectory ?? await getApplicationSupportDirectory();
      // v2 uses the real first frame. Keep it separate from the previous
      // 200ms cache so existing installs refresh their covers once.
      final directory = Directory('${root.path}/video_thumbnails_v2');
      await directory.create(recursive: true);
      final destination = File('${directory.path}/${_stableHash(source)}.jpg');
      if (await destination.exists() && await destination.length() > 0) {
        return destination.path;
      }

      final generated = await VideoThumbnail.thumbnailFile(
        video: source,
        thumbnailPath: directory.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        timeMs: 0,
        quality: 82,
      );
      if (generated == null) return null;
      final generatedFile = File(generated);
      if (!await generatedFile.exists() || await generatedFile.length() == 0) {
        return null;
      }
      if (generatedFile.absolute.path != destination.absolute.path) {
        if (await destination.exists()) await destination.delete();
        await generatedFile.rename(destination.path);
      }
      return destination.path;
    } catch (_) {
      return null;
    }
  }

  static String _stableHash(String value) {
    var hash = 0xcbf29ce484222325;
    for (final byte in value.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
