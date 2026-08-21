import '../model/groupMessageModel.dart';
import '../model/groupConversationModel.dart';
import '../utils/http.dart';
import 'package:flutter/foundation.dart';

// 获取群聊记录
Future<GroupMessageModel> getGroupChatRecord(int groupId, int limit) async {
  try {
    final httpUtil = HttpUtil();
    final response = await httpUtil.post(
      '/api/group/groupChatRecord',
      data: {'groupId': groupId, 'limit': limit},
    );

    if (response.statusCode == 200) {
      if (response.data['code'] == 100) {
        return GroupMessageModel.fromJson(response.data);
      } else {
        throw Exception('获取群聊记录失败: ${response.data['code']}');
      }
    } else {
      throw Exception('获取群聊记录失败: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('获取群聊记录失败: $e');
    rethrow;
  }
}

// 获取群聊会话列表
Future<List<GroupConversationModel>> getGroupConversations(
  String userName,
) async {
  try {
    final httpUtil = HttpUtil();
    final response = await httpUtil.post(
      '/api/group/groupConversation',
      data: {'userName': userName},
    );

    if (response.statusCode == 200) {
      if (response.data['code'] == 100) {
        // 修复字段名：将'conversions'改为'conversations'
        List<dynamic> conversations = response.data['conversations'] ?? [];
        return conversations
            .map((conv) => GroupConversationModel.fromJson(conv))
            .toList();
      } else {
        // 当API返回错误码时，返回空列表而不是抛出异常
        // 这样即使群聊会话获取失败，也不会影响单聊会话的获取
        debugPrint('获取群聊会话失败: ${response.data['code']}');
        return [];
      }
    } else {
      // 当HTTP请求失败时，返回空列表而不是抛出异常
      debugPrint('获取群聊会话失败: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    // 当发生其他异常时，返回空列表而不是抛出异常
    debugPrint('获取群聊会话失败: $e');
    return [];
  }
}
