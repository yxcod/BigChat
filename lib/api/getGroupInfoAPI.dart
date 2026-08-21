import '../model/groupInfoModel.dart';
import '../utils/http.dart';
import 'package:flutter/foundation.dart';

// 获取用户的所有群信息
Future<List<GroupInfoModel>> getGroups(String userName) async {
  try {
    final httpUtil = HttpUtil();
    final response = await httpUtil.post(
      '/api/group/getGroups',
      data: {'userName': userName},
    );

    if (response.statusCode == 200) {
      if (response.data['code'] == 100) {
        List<dynamic> groups = response.data['groups'];
        return groups.map((group) => GroupInfoModel.fromJson(group)).toList();
      } else {
        throw Exception('获取群信息失败: ${response.data['code']}');
      }
    } else {
      throw Exception('获取群信息失败: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('获取群信息失败: $e');
    rethrow;
  }
}

// 创建群聊
Future<int> createGroup(String userName, String groupName, int groupId) async {
  try {
    final httpUtil = HttpUtil();
    final response = await httpUtil.post(
      '/api/group/createGroup',
      data: {
        'createUserName': userName,
        'groupName': groupName,
        'groupId': groupId,
      },
    );

    if (response.statusCode == 200) {
      return response.data['code'] ?? 0;
    } else {
      throw Exception('创建群聊失败: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('创建群聊失败: $e');
    rethrow;
  }
}

// 更新群信息
Future<int> updateGroupInfo(
  String userName,
  int groupId,
  String groupName,
  String description,
  int maxMembers,
  int isActive,
  String? groupAvatar,
) async {
  try {
    debugPrint('updateGroupInfo 被调用:');
    debugPrint('userName: $userName');
    debugPrint('groupId: $groupId');
    debugPrint('groupName: $groupName');
    debugPrint('groupName 长度: ${groupName.length}');
    debugPrint('description: $description');
    debugPrint('maxMembers: $maxMembers');
    debugPrint('isActive: $isActive');
    debugPrint('groupAvatar: $groupAvatar');

    final httpUtil = HttpUtil();
    final response = await httpUtil.post(
      '/api/group/updateGroupInfo',
      data: {
        'userName': userName,
        'groupId': groupId,
        'groupName': groupName,
        'description': description,
        'maxMembers': maxMembers,
        'isActive': isActive,
        'groupAvatar': groupAvatar ?? '',
      },
    );

    if (response.statusCode == 200) {
      debugPrint('updateGroupInfo 响应: ${response.data}');
      return response.data['code'] ?? 0;
    } else {
      throw Exception('更新群信息失败: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('更新群信息失败: $e');
    rethrow;
  }
}
