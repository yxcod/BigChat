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
    throw e;
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
        List<dynamic> conversations = response.data['conversions'];
        return conversations
            .map((conv) => GroupConversationModel.fromJson(conv))
            .toList();
      } else {
        throw Exception('获取群聊会话失败: ${response.data['code']}');
      }
    } else {
      throw Exception('获取群聊会话失败: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('获取群聊会话失败: $e');
    throw e;
  }
}
