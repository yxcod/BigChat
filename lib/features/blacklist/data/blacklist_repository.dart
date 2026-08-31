import 'package:dio/dio.dart';

import '../../../core/parsing/json_value_parser.dart';
import '../../../utils/http.dart';

class BlockedUser {
  const BlockedUser({
    required this.userName,
    required this.nickName,
    required this.avatar,
    required this.avatarVersion,
    required this.createdAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
    userName: json['userName']?.toString().trim() ?? '',
    nickName: json['nickName']?.toString().trim() ?? '',
    avatar: json['avatar']?.toString().trim() ?? '',
    avatarVersion: json['avatarVersion'],
    createdAt: JsonValueParser.intValue(json['createdAt']),
  );

  final String userName;
  final String nickName;
  final String avatar;
  final Object? avatarVersion;
  final int createdAt;

  String get displayName => nickName.isEmpty ? userName : nickName;
}

class BlacklistRepository {
  BlacklistRepository({HttpUtil? http}) : _http = http ?? HttpUtil();

  final HttpUtil _http;

  Future<void> block(String targetUserName) async {
    await _post('/api/blacklist/add', targetUserName: targetUserName);
  }

  Future<void> unblock(String targetUserName) async {
    await _post('/api/blacklist/remove', targetUserName: targetUserName);
  }

  Future<List<BlockedUser>> load() async {
    final data = await _post('/api/blacklist/list');
    final payload = data['data'];
    final rawItems = payload is Map ? payload['items'] : null;
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map((item) => BlockedUser.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.userName.isNotEmpty)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    String? targetUserName,
  }) async {
    try {
      final Response<dynamic> response = await _http.post(
        path,
        data: {if (targetUserName != null) 'targetUserName': targetUserName},
      );
      final raw = response.data;
      if (raw is! Map) throw Exception('服务器响应格式错误');
      final result = Map<String, dynamic>.from(raw);
      if (JsonValueParser.intValue(result['code'], fallback: -1) != 100) {
        throw Exception(result['message'] ?? '黑名单操作失败');
      }
      return result;
    } on DioException catch (error) {
      throw Exception(error.error ?? '网络连接失败');
    }
  }
}
