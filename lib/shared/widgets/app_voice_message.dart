import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/media/voice_media.dart';
import '../../core/media/voice_message.dart';
import '../../utils/http.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';
import 'message_action_menu.dart';

typedef VoiceTranscriber =
    Future<VoiceTranscriptionResult> Function({
      required String ownerId,
      required String audioName,
    });

class AppVoiceMessage extends StatefulWidget {
  const AppVoiceMessage({
    super.key,
    required this.source,
    required this.payload,
    required this.isMe,
    this.transcriber,
    this.onDelete,
    this.onQuote,
    this.cacheEnabled = true,
  });

  final String source;
  final VoiceMessagePayload payload;
  final bool isMe;
  final VoiceTranscriber? transcriber;
  final VoidCallback? onDelete;
  final VoidCallback? onQuote;
  final bool cacheEnabled;

  @override
  State<AppVoiceMessage> createState() => _AppVoiceMessageState();
}

class _AppVoiceMessageState extends State<AppVoiceMessage> {
  static AudioPlayer? _activePlayer;
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  bool _loading = false;
  bool _playing = false;
  bool _dragging = false;
  bool _resumeAfterSeek = false;
  double? _dragFraction;
  Duration _position = Duration.zero;
  CancelToken? _downloadCancelToken;
  String? _loadedSource;
  Future<void>? _cachedPreload;
  bool _transcribing = false;
  bool _transcriptVisible = false;
  String? _transcript;

  @override
  void initState() {
    super.initState();
    _stateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      final completed = state.processingState == ProcessingState.completed;
      setState(() => _playing = state.playing && !completed);
      if (completed) {
        _position = Duration.zero;
        unawaited(_player.seek(Duration.zero));
      }
    });
    _positionSubscription = _player.positionStream.listen((position) {
      if (!mounted || _dragging) return;
      setState(() => _position = position);
    });
    _cachedPreload = _preloadCachedSource(widget.source);
  }

  Future<void> _toggle() async {
    if (_loading) return;
    if (_playing) {
      await _player.pause();
      return;
    }
    try {
      if (_activePlayer != null && _activePlayer != _player) {
        await _activePlayer!.pause();
      }
      _activePlayer = _player;
      if (_loadedSource != widget.source) {
        setState(() => _loading = true);
        await _cachedPreload;
        if (_loadedSource != widget.source) await _loadSource();
      }
      if (mounted) setState(() => _loading = false);
      unawaited(_playAndHandleErrors());
    } catch (error) {
      _showPlaybackError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preloadCachedSource(String source) async {
    if (!widget.cacheEnabled) return;
    final cachedPath = await cachedVoicePath(source);
    if (cachedPath == null || !mounted || widget.source != source) return;
    try {
      await _player.setFilePath(cachedPath);
      if (mounted && widget.source == source) _loadedSource = source;
    } catch (_) {
      final cachedFile = File(cachedPath);
      if (await cachedFile.exists()) await cachedFile.delete();
    }
  }

  Future<void> _playAndHandleErrors() async {
    try {
      await _player.play();
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  Duration get _effectiveDuration =>
      _player.duration ?? Duration(milliseconds: widget.payload.durationMs);

  double get _progressFraction =>
      _dragFraction ?? voiceProgressFraction(_position, _effectiveDuration);

  void _startSeeking(double localX, double width) {
    if (width <= 0 || _loading) return;
    _resumeAfterSeek = _playing;
    _dragging = true;
    _updateSeeking(localX, width);
    if (_playing) unawaited(_player.pause());
  }

  void _updateSeeking(double localX, double width) {
    if (!_dragging || width <= 0) return;
    setState(() => _dragFraction = (localX / width).clamp(0.0, 1.0));
  }

  void _finishSeeking() {
    if (!_dragging) return;
    final fraction = _dragFraction ?? 0;
    final shouldResume = _resumeAfterSeek;
    setState(() => _dragging = false);
    unawaited(_seekToFraction(fraction, resume: shouldResume));
  }

  Future<void> _seekToFraction(double fraction, {required bool resume}) async {
    try {
      if (_loadedSource != widget.source) {
        if (mounted) setState(() => _loading = true);
        await _cachedPreload;
        if (_loadedSource != widget.source) await _loadSource();
      }
      final duration = _effectiveDuration;
      final target = Duration(
        milliseconds: (duration.inMilliseconds * fraction.clamp(0.0, 1.0))
            .round(),
      );
      await _player.seek(target);
      if (mounted) {
        setState(() {
          _position = target;
          _dragFraction = null;
          _loading = false;
        });
      }
      if (resume && !_player.playing) unawaited(_playAndHandleErrors());
    } catch (error) {
      _showPlaybackError(error);
      if (mounted) {
        setState(() {
          _dragFraction = null;
          _loading = false;
        });
      }
    }
  }

  void _tapSeek(double localX, double width) {
    if (width <= 0 || _loading) return;
    unawaited(
      _seekToFraction((localX / width).clamp(0.0, 1.0), resume: _playing),
    );
  }

  void _showPlaybackError(Object error) {
    debugPrint('语音播放加载失败: $error, source=${widget.source}');
    if (!mounted) return;
    final isDamaged = error is StateError && error.toString().contains('已损坏');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isDamaged ? '该语音文件已损坏，无法播放' : '语音加载失败，请稍后重试')),
    );
  }

  Future<void> _loadSource() async {
    if (!widget.cacheEnabled) {
      await _player.setUrl(widget.source);
      _loadedSource = widget.source;
      return;
    }
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

  String get _audioOwnerId {
    final payloadOwner = widget.payload.ownerId?.trim() ?? '';
    if (payloadOwner.isNotEmpty) return payloadOwner;
    try {
      return Uri.parse(widget.source).queryParameters['userName'] ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _toggleTranscription() async {
    if (_transcribing) return;
    if (_transcript != null) {
      setState(() => _transcriptVisible = !_transcriptVisible);
      return;
    }
    final ownerId = _audioOwnerId;
    if (ownerId.isEmpty) {
      _showTranscriptionError('无法确定语音发送者');
      return;
    }
    setState(() => _transcribing = true);
    try {
      final transcriber = widget.transcriber ?? HttpUtil().transcribeAudio;
      final result = await transcriber(
        ownerId: ownerId,
        audioName: widget.payload.audioName,
      );
      if (!mounted) return;
      setState(() {
        _transcript = result.text.trim().isEmpty
            ? '未识别到文字'
            : result.text.trim();
        _transcriptVisible = true;
      });
    } catch (error) {
      _showTranscriptionError(
        error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
      );
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  void _showTranscriptionError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.isEmpty ? '语音转文字失败，请稍后重试' : message)),
    );
  }

  Future<void> _playOnSpeaker() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      await _toggle();
    } catch (error) {
      _showPlaybackError(error);
    }
  }

  Future<void> _showVoiceActions(Offset anchor, {Rect? targetRect}) async {
    final action = await showMessageActionMenu(
      context: context,
      anchor: anchor,
      targetRect: targetRect,
      actions: [
        const MessageActionItem(
          type: MessageActionType.speaker,
          label: '免提播放',
          icon: Icons.volume_up_rounded,
        ),
        MessageActionItem(
          type: MessageActionType.transcription,
          label: _transcriptVisible ? '收起文字' : '转文字',
          icon: _transcriptVisible
              ? Icons.comments_disabled_outlined
              : Icons.text_snippet_outlined,
        ),
        if (widget.onDelete != null)
          const MessageActionItem(
            type: MessageActionType.delete,
            label: '删除',
            icon: Icons.delete_outline_rounded,
          ),
        if (widget.onQuote != null)
          const MessageActionItem(
            type: MessageActionType.quote,
            label: '引用',
            icon: Icons.format_quote_rounded,
          ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case MessageActionType.speaker:
        await _playOnSpeaker();
      case MessageActionType.transcription:
        await _toggleTranscription();
      case MessageActionType.delete:
        widget.onDelete?.call();
      case MessageActionType.quote:
        widget.onQuote?.call();
      case MessageActionType.copy:
      case MessageActionType.save:
        break;
    }
  }

  @override
  void didUpdateWidget(covariant AppVoiceMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _downloadCancelToken?.cancel('语音来源已更新');
      _loadedSource = null;
      _cachedPreload = Future<void>.value();
      _position = Duration.zero;
      _dragFraction = null;
      _dragging = false;
      _transcribing = false;
      _transcriptVisible = false;
      _transcript = null;
      unawaited(_player.stop());
    }
  }

  @override
  void dispose() {
    if (_activePlayer == _player) _activePlayer = null;
    _downloadCancelToken?.cancel('语音组件已关闭');
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.payload.durationSeconds;
    final width = voiceBubbleWidth(seconds);
    final foregroundColor = widget.isMe ? Colors.white : context.appTextPrimary;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) => _showVoiceActions(
        details.globalPosition,
        targetRect: messageActionTargetRect(context),
      ),
      child: Column(
        crossAxisAlignment: widget.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: widget.isMe ? AppColors.primary : context.appSurface,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: width,
              height: 50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 34,
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              key: const ValueKey('voice_play_button'),
                              padding: EdgeInsets.zero,
                              onPressed: _toggle,
                              icon: Icon(
                                _playing
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                size: 30,
                                color: foregroundColor,
                              ),
                            ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final progress = _progressFraction;
                          final barCount = (constraints.maxWidth / 5)
                              .floor()
                              .clamp(10, 34);
                          return Semantics(
                            label: '语音播放进度',
                            value: '${(progress * 100).round()}%',
                            child: GestureDetector(
                              key: const ValueKey('voice_progress_track'),
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) => _tapSeek(
                                details.localPosition.dx,
                                constraints.maxWidth,
                              ),
                              onHorizontalDragStart: (details) => _startSeeking(
                                details.localPosition.dx,
                                constraints.maxWidth,
                              ),
                              onHorizontalDragUpdate: (details) =>
                                  _updateSeeking(
                                    details.localPosition.dx,
                                    constraints.maxWidth,
                                  ),
                              onHorizontalDragEnd: (_) => _finishSeeking(),
                              onHorizontalDragCancel: _finishSeeking,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(barCount, (index) {
                                  final normalized = barCount <= 1
                                      ? 0.0
                                      : index / (barCount - 1);
                                  final played = normalized <= progress;
                                  return Container(
                                    width: 2.4,
                                    height: 7.0 + ((index * 7) % 16),
                                    decoration: BoxDecoration(
                                      color: played
                                          ? foregroundColor
                                          : foregroundColor.withValues(
                                              alpha: 0.28,
                                            ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$seconds″',
                      style: TextStyle(fontSize: 12, color: foregroundColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_transcriptVisible && _transcript != null)
            Container(
              width: width,
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: context.appElevatedSurface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.appDivider),
              ),
              child: SelectableText(
                _transcript!,
                style: const TextStyle(
                  color: Color(0xFF333333),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
