import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/media/voice_message.dart';

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
      if (_player.duration == null) await _player.setUrl(widget.source);
      await _player.play();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('语音加载失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    if (_activePlayer == _player) _activePlayer = null;
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
