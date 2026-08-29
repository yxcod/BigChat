import 'dart:io';

import 'package:flutter_base/core/media/image_file_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('image_format_test_');
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  Future<String> write(String name, List<int> bytes) async {
    final file = File('${directory.path}/$name');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  test('detects PNG screenshot bytes even when path ends in jpg', () async {
    final path = await write('screenshot.jpg', const [
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0,
      0,
      0,
      0,
    ]);

    expect(await detectImageExtension(path), 'png');
  });

  test('detects JPEG and WebP magic bytes', () async {
    final jpeg = await write('photo.bin', const [0xff, 0xd8, 0xff, 0]);
    final webp = await write('photo.bin2', 'RIFFxxxxWEBP'.codeUnits);

    expect(await detectImageExtension(jpeg), 'jpg');
    expect(await detectImageExtension(webp), 'webp');
  });

  test('rejects unsupported data', () async {
    final path = await write('not-image.jpg', const [1, 2, 3, 4]);

    expect(() => supportedImageExtension(path), throwsFormatException);
  });
}
