import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/http.dart';
import 'chat_file.dart';

typedef ChatFileDownloadProgress = void Function(double progress);

class ChatFileSaver {
  const ChatFileSaver();

  static const MethodChannel _channel = MethodChannel(
    'com.yxcod.bigchat/file_export',
  );

  /// Downloads the complete remote file to a temporary path, then hands that
  /// path to the platform document picker. The platform copies the file as a
  /// stream, so a 300 MB attachment is never duplicated in Dart heap memory.
  Future<bool> save({
    required String source,
    required String fileName,
    ChatFileDownloadProgress? onProgress,
    Future<void> Function()? beforeChoosingLocation,
  }) async {
    final safeName = chatFileExportName(fileName);
    final directory = await getTemporaryDirectory();
    final exportDirectory = Directory(
      '${directory.path}/chat_file_exports/${DateTime.now().microsecondsSinceEpoch}',
    );
    await exportDirectory.create(recursive: true);
    final temporaryFile = File('${exportDirectory.path}/$safeName');

    try {
      await HttpUtil().downloadFile(
        source,
        temporaryFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call((received / total).clamp(0.0, 1.0));
          }
        },
      );
      if (!await temporaryFile.exists() || await temporaryFile.length() == 0) {
        throw Exception('文件下载失败');
      }
      onProgress?.call(1);
      await beforeChoosingLocation?.call();
      return await _channel.invokeMethod<bool>('saveFile', {
            'sourcePath': temporaryFile.path,
            'fileName': safeName,
          }) ??
          false;
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      if (await exportDirectory.exists()) {
        await exportDirectory.delete();
      }
    }
  }
}
