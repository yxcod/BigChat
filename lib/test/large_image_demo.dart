import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const LargeImageDemoApp());
}

class LargeImageDemoApp extends StatelessWidget {
  const LargeImageDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '大图片加载示例',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LargeImageDemoPage(),
    );
  }
}

class LargeImageDemoPage extends StatefulWidget {
  const LargeImageDemoPage({super.key});

  @override
  State<LargeImageDemoPage> createState() => _LargeImageDemoPageState();
}

class _LargeImageDemoPageState extends State<LargeImageDemoPage> {
  String? _imageUrl;
  File? _cachedImage;
  Uint8List? _imageBytes; // 用于Web平台存储图片数据
  bool _isLoading = false;
  double _progress = 0.0;
  String _status = '请输入图片URL或使用默认示例';

  // 默认的大图片示例URL
  static const String _defaultImageUrl =
      'https://images.unsplash.com/photo-1600880292203-757bb62b4baf?ixlib=rb-1.2.1&auto=format&fit=crop&w=2070&q=80';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('大图片加载演示')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: '图片URL',
                hintText: _defaultImageUrl,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _imageUrl = value;
                });
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _loadImage,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('加载图片'),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: TextStyle(
                color: _status.contains('失败') ? Colors.red : Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    LinearProgressIndicator(value: _progress),
                    Text('${(_progress * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: (_cachedImage != null || _imageBytes != null)
                  ? InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(20.0),
                      minScale: 0.1,
                      maxScale: 4.0,
                      child: _cachedImage != null
                          ? Image.file(_cachedImage!, fit: BoxFit.contain)
                          : Image.memory(_imageBytes!, fit: BoxFit.contain),
                    )
                  : const Center(child: Text('图片将在这里显示')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _progress = 0.0;
      _status = '开始加载图片...';
      _cachedImage = null;
      _imageBytes = null;
    });

    try {
      final url = _imageUrl?.trim() ?? _defaultImageUrl;

      // 创建Dio实例用于下载图片
      final dio = Dio();

      if (kIsWeb) {
        // Web平台：直接下载图片数据为Uint8List
        final response = await dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
          onReceiveProgress: (count, total) {
            if (total != -1) {
              setState(() {
                _progress = count / total;
                _status = '图片下载中... ${(_progress * 100).toStringAsFixed(1)}%';
              });
            }
          },
        );

        setState(() {
          _imageBytes = response.data as Uint8List;
          _status = '图片加载成功！';
        });
      } else {
        // 移动平台：下载到临时目录并保存为文件
        // 获取临时目录
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/${Uri.parse(url).pathSegments.last}';

        // 下载图片并显示进度
        await dio.download(
          url,
          tempPath,
          onReceiveProgress: (count, total) {
            if (total != -1) {
              setState(() {
                _progress = count / total;
                _status = '图片下载中... ${(_progress * 100).toStringAsFixed(1)}%';
              });
            }
          },
        );

        // 保存到缓存
        final file = File(tempPath);
        await DefaultCacheManager().putFile(
          url,
          await file.readAsBytes(),
          key: url,
        );

        setState(() {
          _cachedImage = file;
          _status = '图片加载成功！';
        });
      }
    } catch (e) {
      setState(() {
        _status = '图片加载失败: $e';
      });
      print('图片加载失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// 自定义缓存管理器，用于控制缓存策略
class CustomCacheManager extends CacheManager {
  CustomCacheManager()
    : super(
        Config(
          'custom_image_cache',
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 100,
        ),
      );
}
