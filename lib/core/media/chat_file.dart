import 'dart:convert';
import 'dart:io';

const int maxChatFileBytes = 300 * 1024 * 1024;

class ChatFilePayload {
  const ChatFilePayload({
    required this.storedName,
    required this.originalName,
    required this.sizeBytes,
    required this.ownerId,
  });

  final String storedName;
  final String originalName;
  final int sizeBytes;
  final String ownerId;

  String encode() => jsonEncode({
    'storedName': storedName,
    'originalName': originalName,
    'sizeBytes': sizeBytes,
    'ownerId': ownerId,
  });

  factory ChatFilePayload.parse(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return ChatFilePayload(
          storedName: decoded['storedName']?.toString() ?? '',
          originalName: decoded['originalName']?.toString() ?? '文件',
          sizeBytes: int.tryParse(decoded['sizeBytes']?.toString() ?? '') ?? 0,
          ownerId: decoded['ownerId']?.toString() ?? '',
        );
      }
    } catch (_) {}
    return ChatFilePayload(
      storedName: value,
      originalName: value.isEmpty ? '文件' : value,
      sizeBytes: 0,
      ownerId: '',
    );
  }
}

Future<int> validateChatFile(String path) async {
  final file = File(path);
  if (!await file.exists()) throw Exception('文件不存在或无法访问');
  final length = await file.length();
  if (length <= 0) throw Exception('不能发送空文件');
  if (length > maxChatFileBytes) throw Exception('单个文件不能超过300MB');
  return length;
}

String chatFileStoredName({
  required String ownerId,
  required String targetId,
  required int messageId,
  required String originalName,
}) {
  final extensionIndex = originalName.lastIndexOf('.');
  final rawExtension = extensionIndex >= 0
      ? originalName.substring(extensionIndex + 1).toLowerCase()
      : '';
  final extension = RegExp(r'^[a-z0-9]{1,12}$').hasMatch(rawExtension)
      ? '.$rawExtension'
      : '';
  final safeOwner = ownerId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  final safeTarget = targetId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  return '${safeOwner}_${safeTarget}_$messageId$extension';
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
