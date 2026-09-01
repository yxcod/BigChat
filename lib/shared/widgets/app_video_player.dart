import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/video_media.dart';
import '../../core/media/chat_media_saver.dart';
import '../../core/media/video_thumbnail_cache.dart';
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
    this.autoCacheRemote = false,
    this.fileName,
    this.allowSave = true,
    this.onLongPress,
  });

  final String source;
  final bool isLocal;
  final double width;
  final double height;
  final double? uploadProgress;
  final bool uploadFailed;
  final bool autoCacheRemote;
  final String? fileName;
  final bool allowSave;
  final VoidCallback? onLongPress;

  @override
  State<AppVideoPreview> createState() => _AppVideoPreviewState();
}

class _AppVideoPreviewState extends State<AppVideoPreview> {
  VideoPlayerController? _controller;
  Object? _previewError;
  int _loadGeneration = 0;
  String? _playbackSource;
  bool _playbackIsLocal = false;
  CancelToken? _previewDownloadCancelToken;
  bool _isDownloading = false;
  double? _downloadProgress;
  String? _thumbnailPath;

  bool get _isUploading =>
      widget.uploadProgress != null && widget.uploadProgress! < 1;
  bool get _isTransferring => _isUploading || _isDownloading;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  @override
  void didUpdateWidget(covariant AppVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.isLocal != widget.isLocal ||
        oldWidget.autoCacheRemote != widget.autoCacheRemote) {
      _initializePreview();
    }
  }

  Future<void> _initializePreview() async {
    final generation = ++_loadGeneration;
    _previewDownloadCancelToken?.cancel('视频预览已更新');
    _previewDownloadCancelToken = null;
    final previous = _controller;
    _controller = null;
    _previewError = null;
    _playbackSource = null;
    _playbackIsLocal = false;
    _isDownloading = false;
    _downloadProgress = null;
    _thumbnailPath = null;
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

    var resolvedSource = widget.source;
    var resolvedIsLocal = widget.isLocal;
    if (!resolvedIsLocal) {
      final cachedPath = await cachedVideoPath(
        widget.source,
        suggestedFileName: widget.fileName,
      );
      if (!mounted || generation != _loadGeneration) return;
      if (cachedPath != null) {
        resolvedSource = cachedPath;
        resolvedIsLocal = true;
      }
    }

    final thumbnailPath = await VideoThumbnailCache.resolve(resolvedSource);
    if (!mounted || generation != _loadGeneration) return;
    if (thumbnailPath != null) {
      setState(() {
        _thumbnailPath = thumbnailPath;
        _playbackSource = resolvedSource;
        _playbackIsLocal = resolvedIsLocal;
        _previewError = null;
      });
      return;
    }

    if (!resolvedIsLocal && widget.autoCacheRemote) {
      try {
        resolvedSource = await _downloadPreviewToCache(
          widget.source,
          generation,
        );
        resolvedIsLocal = true;
      } catch (error) {
        // Keep the network-preview fallback available when automatic
        // receiving fails; tapping the bubble can still open the player.
        debugPrint('Automatic video receive failed: $error');
      }
      if (!mounted || generation != _loadGeneration) return;
    }

    _playbackSource = resolvedSource;
    _playbackIsLocal = resolvedIsLocal;
    VideoPlayerController createController() => resolvedIsLocal
        ? VideoPlayerController.file(File(resolvedSource))
        : VideoPlayerController.networkUrl(Uri.parse(resolvedSource));

    try {
      try {
        await _initializeController(createController(), generation);
      } catch (_) {
        // A freshly uploaded remote file can briefly be unavailable to the
        // receiver. Retry once instead of permanently showing a broken cover.
        if (resolvedIsLocal || !mounted || generation != _loadGeneration) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted || generation != _loadGeneration) return;
        await _initializeController(createController(), generation);
      }
    } catch (error) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _previewError = error;
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<String> _downloadPreviewToCache(String source, int generation) async {
    final cachePath = await videoCachePath(
      source,
      suggestedFileName: widget.fileName,
    );
    final temporary = File('$cachePath.preview.part');
    if (await temporary.exists()) await temporary.delete();
    final cancelToken = CancelToken();
    _previewDownloadCancelToken = cancelToken;
    if (mounted && generation == _loadGeneration) {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0;
      });
    }

    try {
      await HttpUtil().downloadFile(
        source,
        temporary.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (!mounted || generation != _loadGeneration || total <= 0) return;
          final progress = (received / total).clamp(0.0, 1.0);
          final previousProgress = _downloadProgress ?? 0;
          if (progress < 1 && progress - previousProgress < 0.01) return;
          setState(() => _downloadProgress = progress);
        },
      );
      if (!await temporary.exists() || await temporary.length() <= 0) {
        throw StateError('接收的视频文件为空');
      }
      final cached = File(cachePath);
      if (await cached.exists()) await cached.delete();
      await temporary.rename(cachePath);
      return cachePath;
    } finally {
      if (_previewDownloadCancelToken == cancelToken) {
        _previewDownloadCancelToken = null;
      }
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<void> _initializeController(
    VideoPlayerController controller,
    int generation,
  ) async {
    _controller = controller;
    try {
      await controller.initialize();
    } catch (_) {
      if (_controller == controller) _controller = null;
      await controller.dispose();
      rethrow;
    }

    if (!mounted || generation != _loadGeneration) {
      if (_controller == controller) _controller = null;
      await controller.dispose();
      return;
    }

    // Initialization already exposes the first decoded frame. Seeking and
    // pausing are only best-effort: some remote codecs reject a tiny seek even
    // though normal playback works, which must not turn into a cover error.
    try {
      await controller.seekTo(Duration.zero);
    } catch (error) {
      debugPrint('Video preview initial seek was skipped: $error');
    }
    try {
      await controller.pause();
    } catch (error) {
      debugPrint('Video preview initial pause was skipped: $error');
    }

    if (mounted && generation == _loadGeneration) {
      setState(() {
        _previewError = null;
        _isDownloading = false;
        _downloadProgress = null;
      });
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _previewDownloadCancelToken?.cancel('视频预览已关闭');
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openPlayer() async {
    if (_isTransferring || widget.uploadFailed) return;
    final source = _playbackSource ?? widget.source;
    final isLocal = _playbackSource == null ? widget.isLocal : _playbackIsLocal;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppVideoPlayerPage(
          source: source,
          isLocal: isLocal,
          fileName: widget.fileName,
          allowSave: widget.allowSave,
        ),
      ),
    );
    // The player may have downloaded the remote video into the shared cache.
    // Refresh the bubble after returning so it can immediately use that file.
    if (mounted) await _initializePreview();
  }

  Widget _cover() {
    final thumbnailPath = _thumbnailPath;
    if (thumbnailPath != null) {
      return Image.file(
        File(thumbnailPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackCover(),
      );
    }
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
    return _fallbackCover();
  }

  Widget _fallbackCover() => Container(
    color: const Color(0xFF202124),
    alignment: Alignment.center,
    child: Icon(
      _previewError == null ? Icons.movie_outlined : Icons.video_file_outlined,
      size: 54,
      color: Colors.white38,
    ),
  );

  Widget _centerOverlay() {
    if (widget.uploadFailed) {
      return const CircleAvatar(
        radius: 27,
        backgroundColor: Color(0xB3000000),
        child: Icon(Icons.error_outline, size: 32, color: Colors.white),
      );
    }
    final progress =
        widget.uploadProgress ??
        (_isDownloading ? (_downloadProgress ?? 0) : null);
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
      onLongPress: widget.onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Display the generic cover immediately, then replace it with
              // the generated first frame without leaving a blank area.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey<String>(
                    _thumbnailPath ??
                        ((_controller?.value.isInitialized ?? false)
                            ? 'decoded-first-frame'
                            : 'temporary-cover'),
                  ),
                  child: _cover(),
                ),
              ),
              if (_previewError == null || _isTransferring)
                Center(child: _centerOverlay()),
              if (_previewError != null && !_isTransferring)
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
    this.fileName,
    this.allowSave = true,
  });
  final String source;
  final bool isLocal;
  final String? fileName;
  final bool allowSave;

  @override
  State<AppVideoPlayerPage> createState() => _AppVideoPlayerPageState();
}

class _AppVideoPlayerPageState extends State<AppVideoPlayerPage> {
  VideoPlayerController? _controller;
  final CancelToken _cacheDownloadCancelToken = CancelToken();
  bool _controlsVisible = true;
  bool _downloading = false;
  double? _downloadProgress;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (widget.isLocal) {
        await _useController(VideoPlayerController.file(File(widget.source)));
        return;
      }

      final cachedPath = await cachedVideoPath(
        widget.source,
        suggestedFileName: widget.fileName,
      );
      if (!mounted) return;
      if (cachedPath != null) {
        await _useController(VideoPlayerController.file(File(cachedPath)));
        return;
      }

      try {
        await _useController(
          VideoPlayerController.networkUrl(Uri.parse(widget.source)),
        );
      } catch (networkError) {
        if (!mounted) return;
        await _downloadToCacheAndPlay();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _useController(VideoPlayerController controller) async {
    final previous = _controller;
    _controller = controller;
    await previous?.dispose();
    try {
      await controller.initialize();
      if (!mounted || _controller != controller) {
        await controller.dispose();
        return;
      }
      await controller.play();
      setState(() {
        _error = null;
        _downloading = false;
        _downloadProgress = null;
      });
    } catch (_) {
      if (_controller == controller) _controller = null;
      await controller.dispose();
      rethrow;
    }
  }

  Future<void> _downloadToCacheAndPlay() async {
    setState(() {
      _downloading = true;
      _downloadProgress = null;
    });
    final cachePath = await videoCachePath(
      widget.source,
      suggestedFileName: widget.fileName,
    );
    final temporary = File('$cachePath.part');
    if (await temporary.exists()) await temporary.delete();
    try {
      await HttpUtil().downloadFile(
        widget.source,
        temporary.path,
        cancelToken: _cacheDownloadCancelToken,
        onReceiveProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _downloadProgress = received / total);
          }
        },
      );
      if (!await temporary.exists() || await temporary.length() <= 0) {
        throw StateError('下载的视频文件为空');
      }
      final cached = File(cachePath);
      if (await cached.exists()) await cached.delete();
      await temporary.rename(cachePath);
      if (!mounted) return;
      await _useController(VideoPlayerController.file(File(cachePath)));
    } finally {
      if (await temporary.exists()) await temporary.delete();
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _cacheDownloadCancelToken.cancel('视频页面已关闭');
    _controller?.dispose();
    super.dispose();
  }

  String _time(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  Future<void> _download() async {
    if (_downloading || !widget.allowSave) return;
    setState(() {
      _downloading = true;
      _downloadProgress = null;
    });
    try {
      await const ChatMediaSaver().saveVideo(
        source: widget.source,
        fileName: widget.fileName ?? videoSuggestedName(widget.source),
        localPath: widget.isLocal
            ? widget.source
            : await cachedVideoPath(
                widget.source,
                suggestedFileName: widget.fileName,
              ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('视频已保存到系统相册'),
          duration: const Duration(seconds: 2),
        ),
      );
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('下载失败：${error.message ?? '网络异常'}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存失败，请检查相册权限'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _showSaveMenu() async {
    if (!widget.allowSave || _downloading) return;
    final action = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('save_video_to_gallery'),
              leading: const Icon(Icons.download_rounded),
              title: const Text('保存到本地'),
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == true && mounted) await _download();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialized = controller?.value.isInitialized ?? false;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _controlsVisible = !_controlsVisible),
          onLongPress: _showSaveMenu,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (initialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: VideoPlayer(controller),
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
                      if (widget.allowSave)
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
                        () => controller.value.isPlaying
                            ? controller.pause()
                            : controller.play(),
                      ),
                      icon: Icon(
                        controller!.value.isPlaying
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
                      valueListenable: controller!,
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
                              controller,
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
                              () => controller.setVolume(
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
