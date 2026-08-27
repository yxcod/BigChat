import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../features/chat/domain/chat_realtime_event.dart';
import '../../../utils/gloabl.dart';
import '../data/app_settings_repository.dart';
import '../domain/app_settings.dart';
import '../../groups/application/group_notification_settings_service.dart';

typedef NotificationSettingsLoader = Future<AppSettings> Function();
typedef NotificationVibrator = Future<void> Function();
typedef NotificationSoundPlayer = Future<void> Function(String soundId);
typedef GroupMuteReader = Future<bool> Function(int groupId);

class AppMessageNotice {
  const AppMessageNotice({
    required this.title,
    required this.body,
    required this.event,
  });

  final String title;
  final String body;
  final ChatRealtimeEvent event;
}

class AppNotificationFeedbackService {
  AppNotificationFeedbackService({
    NotificationSettingsLoader? loadSettings,
    NotificationVibrator? vibrate,
    NotificationSoundPlayer? playSound,
    GroupMuteReader? isGroupMuted,
  }) : _loadSettings = loadSettings,
       _vibrate = vibrate ?? _defaultVibrate,
       _playSound = playSound ?? AppNotificationTonePlayer.play,
       _isGroupMuted =
           isGroupMuted ??
           GroupNotificationSettingsService.instance.isCurrentUserMuted;

  final NotificationSettingsLoader? _loadSettings;
  final NotificationVibrator _vibrate;
  final NotificationSoundPlayer _playSound;
  final GroupMuteReader _isGroupMuted;

  Future<AppMessageNotice?> handle(
    ChatRealtimeEvent event, {
    required bool appIsForeground,
    bool conversationIsActive = false,
  }) async {
    if (!appIsForeground ||
        (conversationIsActive &&
            event.type != ChatRealtimeEventType.friendRequestUpdated) ||
        !_isIncomingNotification(event)) {
      return null;
    }
    if (event.type == ChatRealtimeEventType.groupMessage &&
        await _isGroupMuted(event.groupId)) {
      return null;
    }

    final settings = await (_loadSettings?.call() ?? _loadCurrentSettings());
    if (settings.vibrationEnabled) await _vibrate();
    if (settings.messageSoundEnabled) {
      await _playSound(settings.messageSoundId);
    }
    if (!settings.bannerEnabled) return null;

    return AppMessageNotice(
      title: _titleFor(event),
      body: _previewFor(event),
      event: event,
    );
  }

  Future<AppSettings> _loadCurrentSettings() {
    return AppSettingsRepository(ownerId: GlobalUtil().userName ?? '').load();
  }

  bool _isIncomingNotification(ChatRealtimeEvent event) {
    final currentUser = GlobalUtil().userName?.trim() ?? '';
    if (event.type == ChatRealtimeEventType.friendRequestUpdated) {
      final action = event.data['action']?.toString();
      if (action == 'created') {
        return event.data['toUserId']?.toString() == currentUser &&
            event.senderId.isNotEmpty;
      }
      if (action == 'rejected') {
        return event.data['fromUserId']?.toString() == currentUser &&
            event.data['toUserId']?.toString().trim().isNotEmpty == true;
      }
      return false;
    }
    if (event.type != ChatRealtimeEventType.privateMessage &&
        event.type != ChatRealtimeEventType.groupMessage) {
      return false;
    }
    return event.senderId.isNotEmpty && event.senderId != currentUser;
  }

  String _titleFor(ChatRealtimeEvent event) {
    final friend = GlobalUtil().getFriendInfoByUserName(event.senderId);
    final displayName = (friend.nickName ?? '').trim().isNotEmpty
        ? friend.nickName!.trim()
        : event.senderId;
    if (event.type == ChatRealtimeEventType.friendRequestUpdated) {
      return event.data['action'] == 'rejected' ? '好友申请已被拒绝' : '新的好友申请';
    }
    return event.type == ChatRealtimeEventType.groupMessage
        ? '群聊消息 · $displayName'
        : displayName;
  }

  String _previewFor(ChatRealtimeEvent event) {
    if (event.type == ChatRealtimeEventType.friendRequestUpdated) {
      if (event.data['action'] == 'rejected') {
        final nickname = event.data['toNickName']?.toString().trim() ?? '';
        final account = event.data['toUserId']?.toString().trim() ?? '';
        final prefix = nickname.isEmpty ? account : nickname;
        return prefix.isEmpty ? '对方拒绝了你的好友申请' : '$prefix 拒绝了你的好友申请';
      }
      final nickname = event.data['fromNickName']?.toString().trim() ?? '';
      final message = event.data['applyMsg']?.toString().trim() ?? '';
      final prefix = nickname.isEmpty ? event.senderId : nickname;
      return message.isEmpty ? '$prefix 请求添加你为好友' : '$prefix：$message';
    }
    final preview = switch (event.messageType) {
      2 => '[图片]',
      3 => '[语音]',
      4 => '[视频]',
      5 => '[文件]',
      _ => event.content.trim(),
    };
    if (preview.isEmpty) return '收到一条新消息';
    return preview.length <= 48 ? preview : '${preview.substring(0, 48)}…';
  }

  static Future<void> _defaultVibrate() => HapticFeedback.mediumImpact();
}

class AppNotificationTonePlayer {
  const AppNotificationTonePlayer._();

  static Future<void> play(String soundId) async {
    final player = AudioPlayer();
    try {
      final directory = await getTemporaryDirectory();
      final normalizedId = NotificationSound.byId(soundId).id;
      final file = File('${directory.path}/notice_tone_$normalizedId.wav');
      if (!await file.exists()) {
        await file.writeAsBytes(_toneBytes(normalizedId), flush: false);
      }
      await player.setFilePath(file.path);
      await player.play();
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        // Some test and desktop environments do not expose system sounds.
      }
    } finally {
      await player.dispose();
    }
  }

  static Uint8List _toneBytes(String soundId) {
    final frequencies = switch (soundId) {
      'tri_tone' => const [740.0, 980.0, 1240.0],
      'note' => const [784.0],
      'glass' => const [1175.0, 1568.0],
      'bell' => const [659.0, 988.0],
      _ => const [880.0, 660.0],
    };
    const sampleRate = 22050;
    const toneDuration = 0.11;
    const gapDuration = 0.025;
    final segmentSamples = (sampleRate * toneDuration).round();
    final gapSamples = (sampleRate * gapDuration).round();
    final sampleCount =
        frequencies.length * segmentSamples +
        math.max(0, frequencies.length - 1) * gapSamples;
    final dataLength = sampleCount * 2;
    final bytes = ByteData(44 + dataLength);

    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        bytes.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);

    var outputSample = 0;
    for (final frequency in frequencies) {
      for (var sample = 0; sample < segmentSamples; sample++) {
        final progress = sample / segmentSamples;
        final envelope = math.pow(1 - progress, 1.8).toDouble();
        final wave = math.sin(2 * math.pi * frequency * sample / sampleRate);
        final value = (wave * envelope * 0.32 * 32767).round();
        bytes.setInt16(44 + outputSample * 2, value, Endian.little);
        outputSample++;
      }
      if (outputSample < sampleCount) outputSample += gapSamples;
    }
    return bytes.buffer.asUint8List();
  }
}
