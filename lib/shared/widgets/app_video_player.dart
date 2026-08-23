import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/video_media.dart';
import '../../utils/http.dart';

class AppVideoPreview extends StatelessWidget {
  const AppVideoPreview({
    super.key,
    required this.source,
    this.isLocal = false,
    this.width = 210,
    this.height = 150,
  });

  final String source;
  final bool isLocal;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AppVideoPlayerPage(source: source, isLocal: isLocal),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF202124),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.movie_outlined, size: 54, color: Colors.white38),
            CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xAA000000),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 38,
                color: Colors.white,
              ),
            ),
            Positioned(
              right: 9,
              bottom: 7,
              child: Text(
                '视频',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
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
          if (mounted && total > 0)
            setState(() => _downloadProgress = received / total);
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('视频已保存到应用本地：$path')));
    } on DioException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败：${error.message ?? '网络异常'}')),
        );
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
                      builder: (_, value, __) => Row(
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
