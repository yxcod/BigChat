import '../model/groupMemberModel.dart';
import '../utils/http.dart';
import 'package:flutter/foundation.dart';

// 获取群成员信息
Future<List<GroupMemberModel>> getGroupMembers(int groupId) async {
  try {
    final httpUtil = HttpUtil();
    final response = await httpUtil.post(
      '/api/group/getGroupMember',
      data: {'groupId': groupId},
    );

    if (response.statusCode == 200) {
      if (response.data['code'] == 100) {
        List<dynamic> members = response.data['members'];
        return members
            .map((member) => GroupMemberModel.fromJson(member))
            .toList();
      } else {
        throw Exception('获取群成员信息失败: ${response.data['code']}');
      }
    } else {
      throw Exception('获取群成员信息失败: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('获取群成员信息失败: $e');
    throw e;
  }
}

// 拉人进群
Future<int> addGroup(int groupId, List<String> userNames) async {
  try {
    final httpUtil = HttpUtil();
    final response = await httpUtil.post(
      '/api/group/addGroup',
      data: {'groupId': groupId, 'userNames': userNames},
    );

    if (response.statusCode == 200) {
      return response.data['code'] ?? 0;
    } else {
      throw Exception('拉人进群失败: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('拉人进群失败: $e');
    throw e;
  }
}

//移除人员进群
Future<int> minuGroup(int groupId, List<String> userNames) async {
  try {
    final httpUtil = HttpUtil();
    final response = await httpUtil.post(
      '/api/group/minuGroup',
      data: {'groupId': groupId, 'userNames': userNames},
    );

    if (response.statusCode == 200) {
      return response.data['code'] ?? 0;
    } else {
      throw Exception('移除人员进群失败: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('移除人员进群失败: $e');
    throw e;
  }
}

// 更新群成员信息
Future<int> updateGroupMemberInfo(
  String userName,
  int groupId,
  String nickName,
  int role,
) async {
  try {
    final httpUtil = HttpUtil();
    final response = await httpUtil.post(
      '/api/group/updateGroupMemberInfo',
      data: {
        'userName': userName,
        'groupId': groupId,
        'nickName': nickName,
        'role': role,
      },
    );

    if (response.statusCode == 200) {
      return response.data['code'] ?? 0;
    } else {
      throw Exception('更新群成员信息失败: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('更新群成员信息失败: $e');
    throw e;
  }
}
