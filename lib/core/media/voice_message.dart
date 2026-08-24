import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const int maxVoiceDurationSeconds = 60;
const int minVoiceDurationMilliseconds = 700;
const int minVoiceFileBytes = 256;

double voiceBubbleWidth(int durationSeconds) {
  return (126.0 + durationSeconds.clamp(1, 60) * 2.35)
      .clamp(132.0, 267.0)
      .toDouble();
}

double voiceProgressFraction(Duration position, Duration duration) {
  if (duration.inMilliseconds <= 0) return 0;
  return (position.inMilliseconds / duration.inMilliseconds)
      .clamp(0.0, 1.0)
      .toDouble();
}

class VoiceMessagePayload {
  const VoiceMessagePayload({
    required this.audioName,
    required this.durationMs,
    this.ownerId,
  });

  final String audioName;
  final int durationMs;
  final String? ownerId;

  int get durationSeconds => (durationMs / 1000).ceil().clamp(1, 60);

  String encode() => jsonEncode({
    'audioName': audioName,
    'durationMs': durationMs.clamp(0, 60000),
    if (ownerId?.isNotEmpty == true) 'ownerId': ownerId,
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
            ownerId: decoded['ownerId']?.toString(),
          );
        }
      }
    } catch (_) {}
    return VoiceMessagePayload(audioName: value, durationMs: 1000);
  }
}

class VoiceTranscriptionResult {
  const VoiceTranscriptionResult({
    required this.text,
    required this.audioDurationMs,
    required this.cached,
  });

  final String text;
  final int audioDurationMs;
  final bool cached;

  factory VoiceTranscriptionResult.fromJson(Map<dynamic, dynamic> json) {
    return VoiceTranscriptionResult(
      text: json['text']?.toString() ?? '',
      audioDurationMs:
          int.tryParse(json['audioDurationMs']?.toString() ?? '') ?? 0,
      cached: json['cached'] == true,
    );
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

abstract interface class VoiceRecorderController {
  Future<void> start();
  Future<VoiceRecordingResult?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class VoiceRecorder implements VoiceRecorderController {
  final AudioRecorder _recorder = AudioRecorder();
  DateTime? _startedAt;
  String? _path;

  @override
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
        sampleRate: 44100,
        numChannels: 1,
        iosConfig: IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.allowBluetooth,
          ],
        ),
      ),
      path: _path!,
    );
    _startedAt = DateTime.now();
  }

  @override
  Future<VoiceRecordingResult?> stop() async {
    final startedAt = _startedAt;
    final recordedPath = await _recorder.stop();
    _startedAt = null;
    _path = null;
    if (startedAt == null || recordedPath == null) return null;
    final file = File(recordedPath);
    final byteLength = await file.exists() ? await file.length() : 0;
    if (byteLength < minVoiceFileBytes) {
      if (await file.exists()) await file.delete();
      throw Exception('未录到有效声音，请检查麦克风权限或音频设备后重试');
    }
    return VoiceRecordingResult(
      path: recordedPath,
      durationMs: DateTime.now().difference(startedAt).inMilliseconds,
    );
  }

  @override
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

  @override
  Future<void> dispose() => _recorder.dispose();
}
