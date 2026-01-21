import '../model/conversationModel.dart';
import '../utils/http.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

Future<List<ConversationModel>> getConversationApi(String userName) async {
  try {
    Response response = await HttpUtil().post(
      '/api/chat/conversation',
      data: {'userName': userName},
    );
    debugPrint('POST请求成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;
    final conversationList = mapData['conversationList'] as List<dynamic>;
    return conversationList
        .map((item) => ConversationModel.formJSON(item as Map<String, dynamic>))
        .toList();
  } on DioException catch (e) {
    debugPrint('POST请求失败：${e.error}');
    throw Exception(e.error);
  }
}
