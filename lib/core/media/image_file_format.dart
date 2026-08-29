import 'dart:io';

/// Detects the real image format from file bytes instead of trusting the path.
/// iOS screenshots are commonly PNG files even when a caller supplied a JPG
/// upload name, which previously caused the server to reject them with HTTP 415.
Future<String?> detectImageExtension(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final reader = await file.open();
  try {
    final header = await reader.read(12);
    if (header.length >= 3 &&
        header[0] == 0xff &&
        header[1] == 0xd8 &&
        header[2] == 0xff) {
      return 'jpg';
    }
    const png = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    if (_startsWith(header, png)) return 'png';
    if (header.length >= 12 &&
        String.fromCharCodes(header.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(header.sublist(8, 12)) == 'WEBP') {
      return 'webp';
    }
    return null;
  } finally {
    await reader.close();
  }
}

Future<String> supportedImageExtension(String path) async {
  final extension = await detectImageExtension(path);
  if (extension == null) {
    throw const FormatException('仅支持 JPEG、PNG 或 WebP 图片');
  }
  return extension;
}

bool _startsWith(List<int> bytes, List<int> signature) {
  if (bytes.length < signature.length) return false;
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) return false;
  }
  return true;
}
