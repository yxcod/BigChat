import '../model/friendRequestModel.dart';
import '../utils/http.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

Future<List<FriendRequestModel>> getFriendRequestsApi(String userName) async {
  try {
    Response response = await HttpUtil().post(
      '/api/friend/requests',
      data: {'userName': userName},
    );
    debugPrint('获取好友申请列表成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;
    final friendRequests = mapData['applyFriendList'] as List<dynamic>;
    return friendRequests
        .map(
          (item) => FriendRequestModel.fromJSON(item as Map<String, dynamic>),
        )
        .toList();
  } on DioException catch (e) {
    debugPrint('获取好友申请列表失败：${e.error}');
    throw Exception(e.error);
  }
}

/// 处理好友申请响应API
/// requestId: 申请ID
/// requestResult: 处理结果（1：接受，2：拒绝 3:拉黑 4:已读但是未进行操作）
Future<Map<String, dynamic>> handleFriendRequestApi(
  int requestId,
  int requestResult,
) async {
  try {
    Response response = await HttpUtil().post(
      '/api/friend/handleRequest',
      data: {'requestId': requestId, 'requestResult': requestResult},
    );
    debugPrint('处理好友申请成功：${response.data}');
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    debugPrint('处理好友申请失败：${e.error}');
    throw Exception(e.error);
  }
}

//删除好友
Future<Map<String, dynamic>> handledeleteFriendApi(
  String fromUserName,
  String toUserName,
  String sessionId,
) async {
  try {
    Response response = await HttpUtil().post(
      '/api/friend/delete',
      data: {
        'fromUserName': fromUserName,
        'toUserName': toUserName,
        "sessionId": sessionId,
      },
    );
    debugPrint('处理好友删除成功：${response.data}');
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    debugPrint('处理好友删除失败：${e.error}');
    throw Exception(e.error);
  }
}

//修改好友备注
Future<Map<String, dynamic>> updateFriendRemarkApi(
  String currentUserName,
  String friendUserName,
  String remark,
) async {
  try {
    Response response = await HttpUtil().post(
      '/api/friend/updateRemark',
      data: {
        'userName': currentUserName,
        'friendUserName': friendUserName,
        'remark': remark,
      },
    );
    debugPrint('修改好友备注成功：${response.data}');
    return response.data as Map<String, dynamic>;
  } on DioException catch (e) {
    debugPrint('修改好友备注失败：${e.error}');
    throw Exception(e.error);
  }
}

//获取最近添加或拒绝的好友列表
Future<List<RecentFriendModel>> getRecentFriendsApi(String userName) async {
  try {
    Response response = await HttpUtil().post(
      '/api/friend/recentAgreedRequests',
      data: {'userName': userName},
    );
    debugPrint('获取最近添加的好友列表成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;
    final recentFriends = mapData['recentFriendsList'] as List<dynamic>;
    return recentFriends
        .map((item) => RecentFriendModel.fromJSON(item as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    debugPrint('获取最近添加的好友列表失败：${e.error}');
    throw Exception(e.error);
  }
}

/// 发送好友申请API
/// currentUserName: 当前用户的userName
/// targetUserName: 要申请好友的userName
/// requestMessage: 申请信息
Future<bool> sendFriendRequestApi(
  String currentUserName,
  String targetUserName,
  String requestMessage,
) async {
  try {
    Response response = await HttpUtil().post(
      '/api/friend/friendApply',
      data: {
        'fromUserId': currentUserName,
        'toUserId': targetUserName,
        'applyMsg': requestMessage,
      },
    );
    debugPrint('发送好友申请成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;
    final code = mapData['code'] as int?;
    if (code == 100) {
      return true;
    } else if (code == 101) {
      debugPrint('发送好友申请失败：code=101');
      throw Exception('发送好友申请失败');
    } else {
      debugPrint('发送好友申请失败：未知错误码 $code');
      throw Exception('发送好友申请失败，错误码：$code');
    }
  } on DioException catch (e) {
    debugPrint('发送好友申请网络失败：${e.error}');
    throw Exception(e.error);
  }
}
