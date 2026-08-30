import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../features/calls/application/call_coordinator.dart';
import '../features/calls/domain/call_signal.dart';
import '../features/calls/data/rtc_token_repository.dart';
import '../utils/agoraManager.dart';

class VideoCallPage extends StatefulWidget {
  const VideoCallPage({super.key});

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final AgoraManager _agora = AgoraManager();
  final CallCoordinator _coordinator = CallCoordinator.instance;
  final RtcTokenRepository _tokens = RtcTokenRepository();
  Timer? _durationTimer;
  Duration _duration = Duration.zero;
  bool _ending = false;

  AppCallSession? get _session => _coordinator.activeSession.value;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCall());
  }

  Future<void> _initializeCall() async {
    final session = _session;
    if (session == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final statuses = await <Permission>[
      Permission.camera,
      Permission.microphone,
    ].request();
    if (statuses.values.any((status) => !status.isGranted)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要允许摄像头和麦克风权限才能视频通话')));
      }
      await _endCall();
      return;
    }
    try {
      final credential = await _tokens.issue(session);
      await _agora.initialize(appId: credential.appId);
      await _agora.joinChannel(
        channelName: session.signal.channelName,
        token: credential.token,
        uid: credential.uid,
        onRenewToken: () => _renewToken(session),
      );
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted ||
            _agora.connectionState != AgoraCallConnectionState.joined) {
          return;
        }
        setState(() => _duration += const Duration(seconds: 1));
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法加入视频通话：$error')));
      }
      await _endCall();
    }
  }

  Future<void> _renewToken(AppCallSession session) async {
    final credential = await _tokens.issue(session);
    await _agora.renewToken(credential.token);
  }

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    await _coordinator.hangup();
    await _agora.leaveAndRelease();
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    if (!_ending && _session != null && _session!.phase != AppCallPhase.ended) {
      unawaited(_coordinator.hangup());
    }
    unawaited(_agora.leaveAndRelease());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _agora,
        builder: (context, _) {
          final session = _session;
          if (session == null) return const SizedBox.shrink();
          if (_agora.connectionState == AgoraCallConnectionState.joined) {
            _coordinator.markConnected();
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              _buildVideoArea(session),
              _buildTopStatus(session),
              _buildControls(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoArea(AppCallSession session) {
    final engine = _agora.engine;
    if (engine == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final remote = _agora.remoteUids.toList(growable: false);
    if (session.signal.isGroup) {
      final tiles = <Widget>[
        _localVideo(engine),
        ...remote.map((uid) => _remoteVideo(engine, uid)),
      ];
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(8, 94, 8, 126),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: tiles.length <= 2 ? 1 : 2,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: tiles.length <= 2 ? 0.9 : 0.72,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, index) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: tiles[index],
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (remote.isEmpty)
          const ColoredBox(
            color: Color(0xFF171A1E),
            child: Center(
              child: Text('等待对方进入通话…', style: TextStyle(color: Colors.white70)),
            ),
          )
        else
          _remoteVideo(engine, remote.first),
        Positioned(
          right: 16,
          top: 104,
          width: 112,
          height: 158,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _localVideo(engine),
          ),
        ),
      ],
    );
  }

  Widget _localVideo(RtcEngine engine) {
    if (!_agora.isLocalVideoEnabled) {
      return const ColoredBox(
        color: Color(0xFF262A30),
        child: Center(
          child: Icon(Icons.videocam_off, color: Colors.white54, size: 42),
        ),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _remoteVideo(RtcEngine engine, int uid) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _session!.signal.channelName),
      ),
    );
  }

  Widget _buildTopStatus(AppCallSession session) {
    final title = session.signal.isGroup
        ? (session.signal.groupName.isEmpty
              ? '群视频通话'
              : session.signal.groupName)
        : '视频通话';
    final stateText = switch (_agora.connectionState) {
      AgoraCallConnectionState.initializing => '正在初始化…',
      AgoraCallConnectionState.joining => '正在连接…',
      AgoraCallConnectionState.joined => _formatDuration(_duration),
      AgoraCallConnectionState.failed => _agora.errorMessage,
      AgoraCallConnectionState.idle => '准备通话…',
    };
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stateText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xCC000000)],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlButton(
                icon: _agora.isLocalAudioEnabled ? Icons.mic : Icons.mic_off,
                label: _agora.isLocalAudioEnabled ? '静音' : '取消静音',
                active: !_agora.isLocalAudioEnabled,
                onTap: _agora.toggleLocalAudio,
              ),
              _ControlButton(
                icon: _agora.isLocalVideoEnabled
                    ? Icons.videocam
                    : Icons.videocam_off,
                label: _agora.isLocalVideoEnabled ? '关闭摄像头' : '打开摄像头',
                active: !_agora.isLocalVideoEnabled,
                onTap: _agora.toggleLocalVideo,
              ),
              _ControlButton(
                icon: Icons.call_end,
                label: '挂断',
                destructive: true,
                onTap: _endCall,
              ),
              _ControlButton(
                icon: Icons.cameraswitch_rounded,
                label: '翻转',
                onTap: _agora.switchCamera,
              ),
              _ControlButton(
                icon: _agora.speakerEnabled ? Icons.volume_up : Icons.hearing,
                label: _agora.speakerEnabled ? '扬声器' : '听筒',
                active: _agora.speakerEnabled,
                onTap: _agora.toggleSpeaker,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final bool active;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFE94B4B)
        : active
        ? Colors.white
        : Colors.white24;
    return SizedBox(
      width: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkResponse(
            onTap: onTap,
            radius: 28,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(
                icon,
                color: destructive || !active ? Colors.white : Colors.black,
                size: 25,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
