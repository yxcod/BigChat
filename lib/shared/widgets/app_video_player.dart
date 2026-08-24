import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/video_media.dart';
import '../../utils/http.dart';

class AppVideoPreview extends StatefulWidget {
  const AppVideoPreview({
    super.key,
    required this.source,
    this.isLocal = false,
    this.width = 210,
    this.height = 150,
    this.uploadProgress,
    this.uploadFailed = false,
  });

  final String source;
  final bool isLocal;
  final double width;
  final double height;
  final double? uploadProgress;
  final bool uploadFailed;

  @override
  State<AppVideoPreview> createState() => _AppVideoPreviewState();
}

class _AppVideoPreviewState extends State<AppVideoPreview> {
  VideoPlayerController? _controller;
  Object? _previewError;
  int _loadGeneration = 0;

  bool get _isUploading =>
      widget.uploadProgress != null && widget.uploadProgress! < 1;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  @override
  void didUpdateWidget(covariant AppVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.isLocal != widget.isLocal) {
      _initializePreview();
    }
  }

  Future<void> _initializePreview() async {
    final generation = ++_loadGeneration;
    final previous = _controller;
    _controller = null;
    _previewError = null;
    if (mounted) setState(() {});
    await previous?.dispose();
    if (!mounted || generation != _loadGeneration) return;

    if (widget.source.trim().isEmpty ||
        (widget.isLocal && !File(widget.source).existsSync())) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _previewError = StateError('视频文件不存在'));
      }
      return;
    }

    final controller = widget.isLocal
        ? VideoPlayerController.file(File(widget.source))
        : VideoPlayerController.networkUrl(Uri.parse(widget.source));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.seekTo(const Duration(milliseconds: 1));
      await controller.pause();
      if (!mounted || generation != _loadGeneration) {
        await controller.dispose();
        return;
      }
      setState(() {});
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() => _previewError = error);
      }
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  void _openPlayer() {
    if (_isUploading || widget.uploadFailed) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AppVideoPlayerPage(source: widget.source, isLocal: widget.isLocal),
      ),
    );
  }

  Widget _cover() {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      final size = controller.value.size;
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width > 0 ? size.width : widget.width,
            height: size.height > 0 ? size.height : widget.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFF202124),
      alignment: Alignment.center,
      child: Icon(
        _previewError == null
            ? Icons.movie_outlined
            : Icons.video_file_outlined,
        size: 54,
        color: Colors.white38,
      ),
    );
  }

  Widget _centerOverlay() {
    if (widget.uploadFailed) {
      return const CircleAvatar(
        radius: 27,
        backgroundColor: Color(0xB3000000),
        child: Icon(Icons.error_outline, size: 32, color: Colors.white),
      );
    }
    final progress = widget.uploadProgress;
    if (progress != null) {
      final normalized = progress.clamp(0.0, 1.0);
      return Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0x99000000),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.square(
              dimension: 48,
              child: CircularProgressIndicator(
                value: normalized,
                strokeWidth: 3,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
            Text(
              '${(normalized * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return const CircleAvatar(
      radius: 25,
      backgroundColor: Color(0xAA000000),
      child: Icon(Icons.play_arrow_rounded, size: 38, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _openPlayer,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _cover(),
              if (_previewError == null || _isUploading)
                Center(child: _centerOverlay()),
              if (_previewError != null && !_isUploading)
                const Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    '封面加载失败，点击可重试播放',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              if (widget.uploadFailed)
                const Positioned(
                  left: 8,
                  right: 8,
                  bottom: 8,
                  child: Text(
                    '发送失败',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppVideoPlayerPage extends StatefulWidget {
  const AppVideoPlayerPage({
    super.key,
    required this.source,
    this.isLocal = false,
  });
  final String source;
  final bool isLocal;

  @override
  State<AppVideoPlayerPage> createState() => _AppVideoPlayerPageState();
}

class _AppVideoPlayerPageState extends State<AppVideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _controlsVisible = true;
  bool _downloading = false;
  double? _downloadProgress;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = widget.isLocal
        ? VideoPlayerController.file(File(widget.source))
        : VideoPlayerController.networkUrl(Uri.parse(widget.source));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          _controller.play();
          setState(() {});
        })
        .catchError((Object error) {
          if (mounted) setState(() => _error = error);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _download() async {
    if (_downloading || widget.isLocal) return;
    setState(() {
      _downloading = true;
      _downloadProgress = null;
    });
    try {
      final path = await videoDownloadPath(widget.source);
      await HttpUtil().downloadFile(
        widget.source,
        path,
        onReceiveProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('视频已保存到应用本地：$path')));
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：${error.message ?? '网络异常'}')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialized = _controller.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _controlsVisible = !_controlsVisible),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (initialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                )
              else if (_error != null)
                const Center(
                  child: Text(
                    '视频加载失败',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (_controlsVisible) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Spacer(),
                      if (!widget.isLocal)
                        IconButton(
                          onPressed: _downloading ? null : _download,
                          icon: const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                if (initialized)
                  Center(
                    child: IconButton.filledTonal(
                      iconSize: 42,
                      onPressed: () => setState(
                        () => _controller.value.isPlaying
                            ? _controller.pause()
                            : _controller.play(),
                      ),
                      icon: Icon(
                        _controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ),
                if (initialized)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _controller,
                      builder: (context, value, child) => Row(
                        children: [
                          Text(
                            _time(value.position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              colors: const VideoProgressColors(
                                playedColor: Colors.white,
                                bufferedColor: Colors.white38,
                              ),
                            ),
                          ),
                          Text(
                            _time(value.duration),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(
                              () => _controller.setVolume(
                                value.volume == 0 ? 1 : 0,
                              ),
                            ),
                            icon: Icon(
                              value.volume == 0
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (_downloading)
                Positioned(
                  left: 28,
                  right: 28,
                  top: 70,
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    color: Colors.white,
                    backgroundColor: Colors.white24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
