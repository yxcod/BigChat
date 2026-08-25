import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/media/voice_message.dart';
import '../../app/theme/app_theme_context.dart';

class HoldToRecordField extends StatefulWidget {
  const HoldToRecordField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onRecorded,
    required this.onError,
    this.enabled = true,
    this.recorder,
    this.holdDuration = const Duration(milliseconds: 320),
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final Future<void> Function(VoiceRecordingResult recording) onRecorded;
  final ValueChanged<String> onError;
  final bool enabled;
  final VoiceRecorderController? recorder;
  final Duration holdDuration;

  @override
  State<HoldToRecordField> createState() => _HoldToRecordFieldState();
}

class _HoldToRecordFieldState extends State<HoldToRecordField> {
  late final VoiceRecorderController _recorder;
  Timer? _timer;
  Timer? _holdTimer;
  DateTime? _startedAt;
  double? _startY;
  int _elapsedSeconds = 0;
  bool _recording = false;
  bool _cancelRequested = false;
  bool _starting = false;
  bool _pointerHeld = false;

  @override
  void initState() {
    super.initState();
    _recorder = widget.recorder ?? VoiceRecorder();
  }

  void _pointerDown(PointerDownEvent event) {
    if (!widget.enabled || _recording || _starting) return;
    _holdTimer?.cancel();
    _pointerHeld = true;
    _startY = event.position.dy;
    _holdTimer = Timer(widget.holdDuration, () {
      if (_pointerHeld) unawaited(_start(event.position.dy));
    });
  }

  void _pointerMove(PointerMoveEvent event) {
    if (!_recording || _startY == null) return;
    final shouldCancel = _startY! - event.position.dy > 70;
    if (shouldCancel != _cancelRequested) {
      HapticFeedback.selectionClick();
      setState(() => _cancelRequested = shouldCancel);
    }
  }

  void _pointerUp() {
    _holdTimer?.cancel();
    _pointerHeld = false;
    if (_recording) unawaited(_finish(send: !_cancelRequested));
  }

  void _pointerCancel() {
    _holdTimer?.cancel();
    _pointerHeld = false;
    if (_recording) unawaited(_finish(send: false));
  }

  Future<void> _start(double globalY) async {
    if (!widget.enabled || _recording || _starting) return;
    widget.focusNode.unfocus();
    setState(() {
      _starting = true;
      _startY = globalY;
    });
    try {
      await _recorder.start();
      if (!_pointerHeld) {
        await _recorder.cancel();
        if (mounted) setState(() => _starting = false);
        return;
      }
      if (!mounted) {
        await _recorder.cancel();
        return;
      }
      HapticFeedback.mediumImpact();
      _startedAt = DateTime.now();
      setState(() {
        _starting = false;
        _recording = true;
        _cancelRequested = false;
        _elapsedSeconds = 0;
      });
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || _startedAt == null) return;
        final elapsed = DateTime.now().difference(_startedAt!);
        setState(() => _elapsedSeconds = elapsed.inSeconds);
        if (elapsed.inSeconds >= maxVoiceDurationSeconds) {
          unawaited(_finish(send: true));
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _starting = false);
        widget.onError(error.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _finish({required bool send}) async {
    _pointerHeld = false;
    if (!_recording) return;
    _timer?.cancel();
    final cancel = !send || _cancelRequested;
    setState(() {
      _recording = false;
      _cancelRequested = false;
      _elapsedSeconds = 0;
    });
    if (cancel) {
      await _recorder.cancel();
      return;
    }
    VoiceRecordingResult? result;
    try {
      result = await _recorder.stop();
    } catch (error) {
      widget.onError(error.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (result == null) return;
    if (result.durationMs < minVoiceDurationMilliseconds) {
      final file = File(result.path);
      if (await file.exists()) await file.delete();
      widget.onError('录音时间太短');
      return;
    }
    await widget.onRecorded(result);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _timer?.cancel();
    unawaited(_disposeRecorder());
    super.dispose();
  }

  Future<void> _disposeRecorder() async {
    if (_recording || _starting) await _recorder.cancel();
    await _recorder.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _pointerDown,
      onPointerMove: _pointerMove,
      onPointerUp: (_) => _pointerUp(),
      onPointerCancel: (_) => _pointerCancel(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _cancelRequested
              ? Colors.red.shade50
              : (_recording
                    ? (context.isDarkMode
                          ? const Color(0xFF183326)
                          : Colors.green.shade50)
                    : context.appSearchBackground),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: _recording
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _cancelRequested ? Icons.delete_outline : Icons.mic,
                    size: 19,
                    color: _cancelRequested ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _cancelRequested
                        ? '松开取消'
                        : '松开发送  ${_elapsedSeconds.clamp(0, 60)}″  ·  上滑取消',
                    style: TextStyle(
                      color: _cancelRequested
                          ? Colors.red
                          : context.appTextPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              )
            : TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: widget.enabled && !_starting && !_recording,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                onTap: widget.focusNode.requestFocus,
                enableInteractiveSelection: false,
                enableSuggestions: true,
                autocorrect: true,
                style: TextStyle(color: context.appTextPrimary),
                decoration: InputDecoration.collapsed(
                  hintText: '长按发送语音',
                  hintStyle: TextStyle(color: context.appTextSecondary),
                ),
              ),
      ),
    );
  }
}
