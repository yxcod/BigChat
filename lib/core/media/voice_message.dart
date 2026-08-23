import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const int maxVoiceDurationSeconds = 60;
const int minVoiceDurationMilliseconds = 700;

class VoiceMessagePayload {
  const VoiceMessagePayload({
    required this.audioName,
    required this.durationMs,
  });

  final String audioName;
  final int durationMs;

  int get durationSeconds => (durationMs / 1000).ceil().clamp(1, 60);

  String encode() => jsonEncode({
    'audioName': audioName,
    'durationMs': durationMs.clamp(0, 60000),
  });

  static VoiceMessagePayload parse(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final name = decoded['audioName']?.toString() ?? '';
        final duration = decoded['durationMs'];
        if (name.isNotEmpty) {
          return VoiceMessagePayload(
            audioName: name,
            durationMs: duration is num
                ? duration.toInt().clamp(0, 60000)
                : int.tryParse(duration?.toString() ?? '')?.clamp(0, 60000) ??
                      1000,
          );
        }
      }
    } catch (_) {}
    return VoiceMessagePayload(audioName: value, durationMs: 1000);
  }
}

String chatVoicePreview(String content) {
  try {
    final decoded = jsonDecode(content);
    if (decoded is Map &&
        (decoded['audioName']?.toString().isNotEmpty ?? false)) {
      return '[语音]';
    }
  } catch (_) {}
  return content;
}

class VoiceRecordingResult {
  const VoiceRecordingResult({required this.path, required this.durationMs});
  final String path;
  final int durationMs;
}

class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;
  String? _path;

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw Exception('未获得麦克风权限');
    }
    final directory = await getTemporaryDirectory();
    final voiceDirectory = Directory('${directory.path}/chat_voice');
    if (!await voiceDirectory.exists()) {
      await voiceDirectory.create(recursive: true);
    }
    _path =
        '${voiceDirectory.path}/voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: _path!,
    );
    _startedAt = DateTime.now();
  }

  Future<VoiceRecordingResult?> stop() async {
    final startedAt = _startedAt;
    final recordedPath = await _recorder.stop();
    _startedAt = null;
    _path = null;
    if (startedAt == null || recordedPath == null) return null;
    return VoiceRecordingResult(
      path: recordedPath,
      durationMs: DateTime.now().difference(startedAt).inMilliseconds,
    );
  }

  Future<void> cancel() async {
    final path = _path;
    await _recorder.cancel();
    _startedAt = null;
    _path = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
