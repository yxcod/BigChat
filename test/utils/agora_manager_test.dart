import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_base/utils/agoraManager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('configures the default audio route before joining a channel', () async {
    final engine = _FakeRtcEngine();
    final manager = AgoraManager.testing(engineFactory: () => engine);

    await manager.initialize(appId: '0123456789abcdef0123456789abcdef');

    expect(engine.calls, [
      'initialize',
      'registerEventHandler',
      'enableVideo',
      'enableAudio',
      'setDefaultAudioRouteToSpeakerphone',
      'startPreview',
    ]);
    expect(engine.calls, isNot(contains('setEnableSpeakerphone')));

    await manager.leaveAndRelease();
  });
}

class _FakeRtcEngine implements RtcEngine {
  final List<String> calls = <String>[];

  @override
  Future<void> initialize(RtcEngineContext context) async {
    calls.add('initialize');
  }

  @override
  void registerEventHandler(RtcEngineEventHandler eventHandler) {
    calls.add('registerEventHandler');
  }

  @override
  Future<void> enableVideo() async {
    calls.add('enableVideo');
  }

  @override
  Future<void> enableAudio() async {
    calls.add('enableAudio');
  }

  @override
  Future<void> setDefaultAudioRouteToSpeakerphone(bool defaultToSpeaker) async {
    calls.add('setDefaultAudioRouteToSpeakerphone');
  }

  @override
  Future<void> startPreview({
    VideoSourceType sourceType = VideoSourceType.videoSourceCameraPrimary,
  }) async {
    calls.add('startPreview');
  }

  @override
  Future<void> stopPreview({
    VideoSourceType sourceType = VideoSourceType.videoSourceCameraPrimary,
  }) async {}

  @override
  Future<void> leaveChannel({LeaveChannelOptions? options}) async {}

  @override
  Future<void> release({bool sync = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
