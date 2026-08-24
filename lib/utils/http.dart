import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import './gloabl.dart';
import '../core/network/app_connection_monitor.dart';
import '../core/media/voice_message.dart';

class HttpUtil {
  static final HttpUtil _instance = HttpUtil._internal();
  static late Dio _dio;
  // 使用GlobalUtil实例
  final GlobalUtil _globalUtil = GlobalUtil();

  factory HttpUtil() {
    return _instance;
  }

  HttpUtil._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _globalUtil.baseURL,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json;charset=UTF-8'},
      ),
    );

    // 添加请求拦截器
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // 使用GlobalUtil中的token
          if (_globalUtil.token != null && _globalUtil.token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer ${_globalUtil.token}';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          AppConnectionMonitor.instance.reportHttpReachable();
          // 统一处理响应数据
          if (response.statusCode == 200) {
            return handler.next(response);
          } else {
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                error: '请求失败，状态码：${response.statusCode}',
              ),
            );
          }
        },
        onError: (DioException e, handler) {
          if (e.response != null) {
            AppConnectionMonitor.instance.reportHttpReachable();
          } else if (e.type != DioExceptionType.cancel) {
            AppConnectionMonitor.instance.reportHttpUnavailable();
          }
          // 统一处理错误
          String errorMsg = '网络请求失败';
          if (e.type == DioExceptionType.connectionTimeout) {
            errorMsg = '连接超时';
          } else if (e.type == DioExceptionType.sendTimeout) {
            errorMsg = '发送超时';
          } else if (e.type == DioExceptionType.receiveTimeout) {
            errorMsg = '接收超时';
          } else if (e.type == DioExceptionType.cancel) {
            errorMsg = '请求取消';
          } else if (e.type == DioExceptionType.badResponse) {
            errorMsg = '服务器错误，状态码：${e.response?.statusCode}';
          } else if (e.type == DioExceptionType.unknown) {
            errorMsg = '网络错误，请检查网络连接';
          }

          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              response: e.response,
              error: errorMsg,
            ),
          );
        },
      ),
    );
  }

  // GET请求
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return await _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  // POST请求
  Future<Response> post(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  // PUT请求
  Future<Response> put(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  // DELETE请求
  Future<Response> delete(
    String path, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return await _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  // 上传文件
  Future<Response> upload(
    String path,
    List<MultipartFile> files, {
    String fieldName = 'files',
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    FormData formData = FormData.fromMap({...?data, fieldName: files});

    return await _dio.post(
      path,
      data: formData,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  // 上传图片
  DioMediaType _imageMediaType(String imageName) {
    final extension = imageName.contains('.')
        ? imageName.split('.').last.toLowerCase()
        : 'jpg';
    return DioMediaType('image', extension == 'jpg' ? 'jpeg' : extension);
  }

  Future<bool> uploadImageFile(
    String imageName,
    String filePath, {
    String? userName,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final file = await MultipartFile.fromFile(
      filePath,
      filename: imageName,
      contentType: _imageMediaType(imageName),
    );
    return _uploadImageMultipart(
      imageName,
      file,
      userName: userName,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  Future<bool> uploadImage(
    String imageName,
    Uint8List imageData, {
    String? userName,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final file = MultipartFile.fromBytes(
      imageData,
      filename: imageName,
      contentType: _imageMediaType(imageName),
    );
    return _uploadImageMultipart(
      imageName,
      file,
      userName: userName,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
  }

  Future<bool> _uploadImageMultipart(
    String imageName,
    MultipartFile file, {
    String? userName,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData.fromMap({'file': file});
    final finalUserName = userName ?? (_globalUtil.userName ?? '');
    if (finalUserName.isEmpty) {
      throw Exception('无法获取当前用户信息');
    }

    final uploadQueryParameters = <String, dynamic>{
      ...?queryParameters,
      'userName': finalUserName,
      'imageName': imageName,
    };
    final response = await _dio.post(
      '/api/image/upload',
      data: formData,
      queryParameters: uploadQueryParameters,
      options:
          options ??
          Options(
            sendTimeout: const Duration(seconds: 60),
            receiveTimeout: const Duration(seconds: 30),
          ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );

    // 解析响应数据
    if (response.data != null && response.data is Map<String, dynamic>) {
      final responseData = response.data as Map<String, dynamic>;
      // 检查code值，100表示上传成功
      if (responseData.containsKey('code') && responseData['code'] == 100) {
        return true;
      } else {
        // 上传失败，抛出异常或返回false
        throw Exception('上传失败，错误码: ${responseData['code']}');
      }
    } else {
      // 响应格式错误
      throw Exception('上传失败，响应格式错误');
    }
  }

  DioMediaType _videoMediaType(String videoName) {
    final extension = videoName.contains('.')
        ? videoName.split('.').last.toLowerCase()
        : 'mp4';
    return switch (extension) {
      'mov' => DioMediaType('video', 'quicktime'),
      'm4v' => DioMediaType('video', 'x-m4v'),
      _ => DioMediaType('video', 'mp4'),
    };
  }

  Future<bool> uploadVideoFile(
    String videoName,
    String filePath, {
    String? userName,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final finalUserName = userName ?? (_globalUtil.userName ?? '');
    if (finalUserName.isEmpty) throw Exception('无法获取当前用户信息');
    final file = await MultipartFile.fromFile(
      filePath,
      filename: videoName,
      contentType: _videoMediaType(videoName),
    );
    final response = await _dio.post(
      '/api/video/upload',
      data: FormData.fromMap({'file': file}),
      queryParameters: {'userName': finalUserName, 'videoName': videoName},
      options: Options(
        sendTimeout: const Duration(minutes: 20),
        receiveTimeout: const Duration(minutes: 2),
      ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
    final data = response.data;
    if (data is Map && data['code'] == 100) return true;
    throw Exception(data is Map ? (data['message'] ?? '视频上传失败') : '视频上传失败');
  }

  Future<bool> uploadAudioFile(
    String audioName,
    String filePath, {
    String? userName,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final finalUserName = userName ?? (_globalUtil.userName ?? '');
    if (finalUserName.isEmpty) throw Exception('无法获取当前用户信息');
    final file = await MultipartFile.fromFile(
      filePath,
      filename: audioName,
      contentType: DioMediaType('audio', 'mp4'),
    );
    final response = await _dio.post(
      '/api/audio/upload',
      data: FormData.fromMap({'file': file}),
      queryParameters: {'userName': finalUserName, 'audioName': audioName},
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 1),
      ),
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
    final data = response.data;
    if (data is Map && data['code'] == 100) return true;
    throw Exception(data is Map ? (data['message'] ?? '语音上传失败') : '语音上传失败');
  }

  Future<VoiceTranscriptionResult> transcribeAudio({
    required String ownerId,
    required String audioName,
  }) async {
    final userName = _globalUtil.userName ?? '';
    if (userName.isEmpty || ownerId.isEmpty || audioName.isEmpty) {
      throw Exception('语音信息不完整');
    }
    try {
      final response = await _dio.post(
        '/api/audio/transcribe',
        data: {
          'userName': userName,
          'ownerId': ownerId,
          'audioName': audioName,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );
      final data = response.data;
      if (data is Map && data['code'] == 100) {
        return VoiceTranscriptionResult.fromJson(data);
      }
      throw Exception(data is Map ? (data['message'] ?? '语音转文字失败') : '语音转文字失败');
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map && data['message']?.toString().isNotEmpty == true) {
        throw Exception(data['message'].toString());
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> downloadFile(
    String url,
    String savePath, {
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) {
    return _dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
      options: Options(receiveTimeout: const Duration(minutes: 20)),
    );
  }

  // 下载文件
  Future<Response> download(
    String url,
    String savePath, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return await _dio.download(
      url,
      savePath,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  // 标记消息为已读
  Future<bool> markMessagesAsRead(
    String receiverName,
    List<int> msgIds, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      // 调用服务器API标记消息为已读
      Response response = await _dio.post(
        '/api/chat/markAsRead',
        data: {
          'senderName': _globalUtil.userName,
          'receiverName': receiverName,
          'msgIds': msgIds,
        },
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );

      // 解析响应数据
      if (response.data != null && response.data is Map<String, dynamic>) {
        Map<String, dynamic> responseData =
            response.data as Map<String, dynamic>;
        // 检查code值，100表示成功
        return responseData.containsKey('code') && responseData['code'] == 100;
      } else {
        // 响应格式错误
        throw Exception('标记消息已读失败，响应格式错误');
      }
    } catch (e) {
      // 处理异常
      debugPrint('标记消息已读失败: $e');
      return false;
    }
  }
}
