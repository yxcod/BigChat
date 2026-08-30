import 'package:dio/dio.dart';

import '../../../utils/http.dart';
import '../domain/call_signal.dart';

class RtcCredential {
  const RtcCredential({
    required this.appId,
    required this.token,
    required this.uid,
    required this.expiresAt,
  });

  final String appId;
  final String token;
  final int uid;
  final DateTime expiresAt;
}

class RtcTokenRepository {
  RtcTokenRepository({HttpUtil? http}) : _http = http ?? HttpUtil();

  final HttpUtil _http;

  Future<RtcCredential> issue(AppCallSession session) async {
    final signal = session.signal;
    final peerId = session.isCaller ? signal.receiverId : signal.senderId;
    late final Response<dynamic> response;
    try {
      response = await _http.post(
        '/api/calls/rtc-token',
        data: {
          'callId': signal.callId,
          'channelName': signal.channelName,
          'callKind': signal.kind.name,
          if (signal.isGroup) 'groupId': signal.groupId,
          if (!signal.isGroup) 'peerId': peerId,
        },
      );
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 503) throw StateError('视频通话服务未配置');
      if (status == 401 || status == 403) {
        throw StateError('当前账号无权加入此视频通话');
      }
      rethrow;
    }
    final raw = response.data;
    if (raw is! Map || raw['code'] != 100) {
      throw StateError(
        raw is Map ? raw['message']?.toString() ?? '视频通话凭证获取失败' : '视频通话凭证响应无效',
      );
    }
    final appId = raw['appId']?.toString() ?? '';
    final token = raw['token']?.toString() ?? '';
    final uid = int.tryParse(raw['uid']?.toString() ?? '') ?? 0;
    final expiresAt = int.tryParse(raw['expiresAt']?.toString() ?? '') ?? 0;
    if (appId.length != 32 || token.isEmpty || uid <= 0 || expiresAt <= 0) {
      throw StateError('视频通话凭证响应不完整');
    }
    return RtcCredential(
      appId: appId,
      token: token,
      uid: uid,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000),
    );
  }
}
