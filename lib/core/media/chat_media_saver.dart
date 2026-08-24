import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../../utils/http.dart';

class ChatMediaSaver {
  const ChatMediaSaver();

  Future<void> saveImage({
    required String source,
    required String fileName,
  }) async {
    final response = await HttpUtil().get(
      source,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final data = response.data;
    final bytes = data is Uint8List
        ? data
        : Uint8List.fromList(List<int>.from(data as List));
    if (bytes.isEmpty) throw Exception('图片下载失败');
    final result = await SaverGallery.saveImage(
      bytes,
      fileName: _safeFileName(fileName, fallback: 'chat_image.jpg'),
      quality: 100,
      skipIfExists: false,
    );
    if (!result.isSuccess) {
      throw Exception(result.errorMessage ?? '图片保存失败');
    }
  }

  Future<void> saveVideo({
    required String source,
    required String fileName,
    String? localPath,
  }) async {
    final existingLocal = localPath == null ? null : File(localPath);
    File? downloaded;
    final String path;
    if (existingLocal != null && await existingLocal.exists()) {
      path = existingLocal.path;
    } else {
      final directory = await getTemporaryDirectory();
      downloaded = File(
        '${directory.path}/${_safeFileName(fileName, fallback: 'chat_video.mp4')}',
      );
      if (await downloaded.exists()) await downloaded.delete();
      await HttpUtil().downloadFile(source, downloaded.path);
      if (!await downloaded.exists() || await downloaded.length() == 0) {
        throw Exception('视频下载失败');
      }
      path = downloaded.path;
    }

    try {
      final result = await SaverGallery.saveFile(
        filePath: path,
        fileName: _safeFileName(fileName, fallback: 'chat_video.mp4'),
        skipIfExists: false,
      );
      if (!result.isSuccess) {
        throw Exception(result.errorMessage ?? '视频保存失败');
      }
    } finally {
      if (downloaded != null && await downloaded.exists()) {
        await downloaded.delete();
      }
    }
  }

  String _safeFileName(String value, {required String fallback}) {
    final normalized = value.split('/').last.split('\\').last.trim();
    if (normalized.isEmpty) return fallback;
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }
}
