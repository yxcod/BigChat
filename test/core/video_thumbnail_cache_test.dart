import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/core/media/video_thumbnail_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('completes after returning an existing cached cover', () async {
    final root = await Directory.systemTemp.createTemp('video-cover-existing-');
    addTearDown(() => root.delete(recursive: true));
    const source = '/tmp/already-cached.mov';
    var hash = 0xcbf29ce484222325;
    for (final byte in source.codeUnits) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
    }
    final hashName = hash.toRadixString(16).padLeft(16, '0');
    final cover = File('${root.path}/video_thumbnails_v2/$hashName.jpg');
    await cover.parent.create(recursive: true);
    await cover.writeAsBytes(const [0xFF, 0xD8, 0xFF, 0xD9]);

    final result = await VideoThumbnailCache.resolve(
      source,
      rootDirectory: root,
    ).timeout(const Duration(seconds: 1));

    expect(result, cover.path);
  });
}
