import 'dart:io';

import 'package:flutter_base/core/media/video_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('video owner is restored from generated file name', () {
    expect(
      videoOwnerFromName('10001_10002_123456.mov', fallbackOwner: 'fallback'),
      '10001',
    );
    expect(videoOwnerFromName('legacy.mp4', fallbackOwner: '10002'), '10002');
  });

  test(
    'uploaded chat video is restored from persistent cache by remote url',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chat_video_cache_test',
      );
      addTearDown(() => root.delete(recursive: true));
      final source = File('${root.path}/picked.mov');
      await source.writeAsBytes(List<int>.generate(32, (index) => index));
      const url =
          'http://example.test/api/video/download?userName=10001&videoName=10001_10002_1.mov';

      final cached = await cacheUploadedVideo(
        source.path,
        url,
        rootDirectory: root,
      );

      expect(cached, isNotNull);
      expect(await File(cached!).readAsBytes(), await source.readAsBytes());
      expect(await cachedVideoPath(url, rootDirectory: root), cached);
    },
  );

  test('empty cached video is ignored', () async {
    final root = await Directory.systemTemp.createTemp('chat_video_cache_test');
    addTearDown(() => root.delete(recursive: true));
    const url =
        'http://example.test/api/video/download?userName=10001&videoName=empty.mp4';
    final path = await videoCachePath(url, rootDirectory: root);
    await File(path).writeAsBytes(const []);

    expect(await cachedVideoPath(url, rootDirectory: root), isNull);
  });

  test('group resource cache keeps the original video extension', () async {
    final root = await Directory.systemTemp.createTemp(
      'group_video_cache_test',
    );
    addTearDown(() => root.delete(recursive: true));
    const url =
        'http://example.test/api/group/resource/download?resourceId=7&fileName=相册视频.mov';

    final path = await videoCachePath(url, rootDirectory: root);

    expect(path, endsWith('.mov'));
    expect(isVideoPath(url), isTrue);
    expect(videoSuggestedName(url), endsWith('.mov'));
  });
}
