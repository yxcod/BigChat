import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/media/voice_media.dart';
import '../../core/media/voice_message.dart';
import '../../utils/http.dart';

class AppVoiceMessage extends StatefulWidget {
  const AppVoiceMessage({
    super.key,
    required this.source,
    required this.payload,
    required this.isMe,
  });

  final String source;
  final VoiceMessagePayload payload;
  final bool isMe;

  @override
  State<AppVoiceMessage> createState() => _AppVoiceMessageState();
}

class _AppVoiceMessageState extends State<AppVoiceMessage> {
  static AudioPlayer? _activePlayer;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _loading = false;
  bool _playing = false;
  CancelToken? _downloadCancelToken;
  String? _loadedSource;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      setState(() => _playing = state.playing && !completed);
      if (completed) unawaited(_player.seek(Duration.zero));
    });
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player.pause();
      return;
    }
    setState(() => _loading = true);
    try {
      if (_activePlayer != null && _activePlayer != _player) {
        await _activePlayer!.pause();
      }
      _activePlayer = _player;
      if (_loadedSource != widget.source || _player.duration == null) {
        await _loadSource();
      }
      await _player.play();
    } catch (error) {
      debugPrint('语音播放加载失败: $error, source=${widget.source}');
      if (mounted) {
        final isDamaged =
            error is StateError && error.toString().contains('已损坏');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isDamaged ? '该语音文件已损坏，无法播放' : '语音加载失败，请稍后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSource() async {
    final cachedPath = await cachedVoicePath(widget.source);
    if (cachedPath != null) {
      await _player.setFilePath(cachedPath);
      _loadedSource = widget.source;
      return;
    }

    final destinationPath = await voiceCachePath(widget.source);
    final temporaryPath = '$destinationPath.part';
    final temporary = File(temporaryPath);
    if (await temporary.exists()) await temporary.delete();
    final cancelToken = CancelToken();
    _downloadCancelToken = cancelToken;
    try {
      await HttpUtil().downloadFile(
        widget.source,
        temporaryPath,
        cancelToken: cancelToken,
      );
      if (!await temporary.exists() ||
          await temporary.length() < minVoiceFileBytes) {
        throw StateError('语音文件已损坏或没有声音数据');
      }
      final destination = File(destinationPath);
      if (await destination.exists()) await destination.delete();
      await temporary.rename(destinationPath);
      await _player.setFilePath(destinationPath);
      _loadedSource = widget.source;
    } finally {
      if (_downloadCancelToken == cancelToken) _downloadCancelToken = null;
      if (await temporary.exists()) await temporary.delete();
    }
  }

  @override
  void didUpdateWidget(covariant AppVoiceMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _loadedSource = null;
      unawaited(_player.stop());
    }
  }

  @override
  void dispose() {
    if (_activePlayer == _player) _activePlayer = null;
    _downloadCancelToken?.cancel('语音组件已关闭');
    _stateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.payload.durationSeconds;
    final width = (88.0 + seconds * 2.1).clamp(92.0, 210.0);
    return Material(
      color: widget.isMe ? Colors.blue[100] : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _toggle,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: width,
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              textDirection: widget.isMe
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              children: [
                if (_loading)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    _playing ? Icons.pause_rounded : Icons.volume_up_rounded,
                    size: 22,
                  ),
                const SizedBox(width: 7),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      7,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 2.5,
                        height: _playing
                            ? 8.0 + ((index * 7) % 15)
                            : 5.0 + ((index * 5) % 11),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text('$seconds″', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
