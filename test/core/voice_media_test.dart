import 'dart:io';

import 'package:flutter_base/core/media/voice_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uploaded voice is restored from persistent cache by remote url',
    () async {
      final root = await Directory.systemTemp.createTemp('voice_cache_test');
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/recording.m4a');
      await source.writeAsBytes([0, 1, 2, 3]);
      const url =
          'http://example.test/api/audio/download?userName=alice&audioName=voice_1.m4a';

      final cached = await cacheUploadedVoice(
        source.path,
        url,
        rootDirectory: root,
      );

      expect(cached, isNotNull);
      expect(await File(cached!).readAsBytes(), [0, 1, 2, 3]);
      expect(await cachedVoicePath(url, rootDirectory: root), cached);
    },
  );

  test('empty voice cache is ignored', () async {
    final root = await Directory.systemTemp.createTemp('voice_cache_empty');
    addTearDown(() => root.delete(recursive: true));
    const url =
        'http://example.test/api/audio/download?userName=bob&audioName=voice_2.m4a';
    final path = await voiceCachePath(url, rootDirectory: root);
    await File(path).create(recursive: true);

    expect(await cachedVoicePath(url, rootDirectory: root), isNull);
  });
}
