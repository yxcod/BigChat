import '../utils/http.dart';

Future<Map<String, dynamic>> deletePrivateChatHistoryApi({
  required String userName,
  required String peerUserName,
  required String conversationId,
}) async {
  final response = await HttpUtil().post(
    '/api/chat/deleteChatHistory',
    data: {
      'userName': userName,
      'peerUserName': peerUserName,
      'conversationId': conversationId,
    },
  );
  return Map<String, dynamic>.from(response.data as Map);
}

Future<Map<String, dynamic>> deleteGroupChatHistoryApi({
  required String userName,
  required int groupId,
}) async {
  final response = await HttpUtil().post(
    '/api/group/deleteGroupChatHistory',
    data: {'userName': userName, 'groupId': groupId},
  );
  return Map<String, dynamic>.from(response.data as Map);
}
