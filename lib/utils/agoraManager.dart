import 'dart:collection';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

enum AgoraCallConnectionState { idle, initializing, joining, joined, failed }

class AgoraManager extends ChangeNotifier {
  AgoraManager._internal();

  static final AgoraManager _instance = AgoraManager._internal();
  factory AgoraManager() => _instance;

  RtcEngine? _engine;
  int? _localUid;
  final Set<int> _remoteUids = <int>{};
  bool _isLocalVideoEnabled = true;
  bool _isLocalAudioEnabled = true;
  bool _speakerEnabled = true;
  AgoraCallConnectionState _connectionState = AgoraCallConnectionState.idle;
  String _errorMessage = '';
  String _channelName = '';
  String _appId = '';
  Future<void> Function()? _tokenRenewer;
  bool _renewingToken = false;

  Future<void> initialize({required String appId}) async {
    if (_engine != null) {
      if (_appId != appId) throw StateError('视频项目配置发生变化，请重新进入通话');
      return;
    }
    _setState(AgoraCallConnectionState.initializing);
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      engine.registerEventHandler(_eventHandler());
      await engine.enableVideo();
      await engine.enableAudio();
      await engine.setEnableSpeakerphone(true);
      await engine.startPreview();
      _engine = engine;
      _appId = appId;
      _localUid = null;
      _remoteUids.clear();
      _isLocalVideoEnabled = true;
      _isLocalAudioEnabled = true;
      _speakerEnabled = true;
      _errorMessage = '';
      notifyListeners();
    } catch (error) {
      _errorMessage = '视频引擎初始化失败：$error';
      _setState(AgoraCallConnectionState.failed);
      rethrow;
    }
  }

  RtcEngineEventHandler _eventHandler() {
    return RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        _localUid = connection.localUid;
        _setState(AgoraCallConnectionState.joined);
      },
      onRejoinChannelSuccess: (connection, elapsed) {
        _localUid = connection.localUid;
        _setState(AgoraCallConnectionState.joined);
      },
      onLeaveChannel: (connection, stats) {
        _remoteUids.clear();
        _localUid = null;
        _channelName = '';
        _setState(AgoraCallConnectionState.idle);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        _remoteUids.add(remoteUid);
        notifyListeners();
      },
      onUserOffline: (connection, remoteUid, reason) {
        _remoteUids.remove(remoteUid);
        notifyListeners();
      },
      onConnectionStateChanged: (connection, state, reason) {
        if (state == ConnectionStateType.connectionStateFailed) {
          _errorMessage = '视频网络连接失败，请检查网络后重试';
          _setState(AgoraCallConnectionState.failed);
        }
      },
      onTokenPrivilegeWillExpire: (connection, token) {
        _requestTokenRenewal();
      },
      onRequestToken: (connection) => _requestTokenRenewal(),
      onError: (error, message) {
        _errorMessage = 'Agora $error：$message';
        _setState(AgoraCallConnectionState.failed);
      },
    );
  }

  Future<void> joinChannel({
    required String channelName,
    required String token,
    int uid = 0,
    Future<void> Function()? onRenewToken,
  }) async {
    final engine = _engine;
    if (engine == null) throw StateError('视频引擎尚未初始化');
    _channelName = channelName;
    _tokenRenewer = onRenewToken;
    _setState(AgoraCallConnectionState.joining);
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  Future<void> renewToken(String token) async {
    if (token.isEmpty || _engine == null) return;
    await _engine!.renewToken(token);
    _errorMessage = '';
    notifyListeners();
  }

  void _requestTokenRenewal() {
    if (_renewingToken || _tokenRenewer == null) return;
    _renewingToken = true;
    _tokenRenewer!()
        .catchError((Object error) {
          _errorMessage = '视频通话凭证续期失败，请检查网络';
          notifyListeners();
        })
        .whenComplete(() => _renewingToken = false);
  }

  Future<void> toggleLocalVideo() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_isLocalVideoEnabled;
    await engine.muteLocalVideoStream(!next);
    await engine.enableLocalVideo(next);
    _isLocalVideoEnabled = next;
    notifyListeners();
  }

  Future<void> toggleLocalAudio() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_isLocalAudioEnabled;
    await engine.muteLocalAudioStream(!next);
    _isLocalAudioEnabled = next;
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    final engine = _engine;
    if (engine == null) return;
    final next = !_speakerEnabled;
    await engine.setEnableSpeakerphone(next);
    _speakerEnabled = next;
    notifyListeners();
  }

  Future<void> switchCamera() async => _engine?.switchCamera();

  Future<void> leaveAndRelease() async {
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      try {
        await engine.stopPreview();
        await engine.leaveChannel();
      } finally {
        await engine.release();
      }
    }
    _localUid = null;
    _remoteUids.clear();
    _channelName = '';
    _appId = '';
    _tokenRenewer = null;
    _renewingToken = false;
    _errorMessage = '';
    _connectionState = AgoraCallConnectionState.idle;
    notifyListeners();
  }

  void _setState(AgoraCallConnectionState value) {
    _connectionState = value;
    notifyListeners();
  }

  int? get localUid => _localUid;
  UnmodifiableSetView<int> get remoteUids =>
      UnmodifiableSetView<int>(_remoteUids);
  bool get isLocalVideoEnabled => _isLocalVideoEnabled;
  bool get isLocalAudioEnabled => _isLocalAudioEnabled;
  bool get speakerEnabled => _speakerEnabled;
  RtcEngine? get engine => _engine;
  AgoraCallConnectionState get connectionState => _connectionState;
  String get errorMessage => _errorMessage;
  String get channelName => _channelName;
}
