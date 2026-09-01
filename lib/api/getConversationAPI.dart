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
    //debugPrint('POST请求成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;
    final code = mapData['code'];
    if (code != null && code != 100 && code != 200) {
      throw Exception('获取会话列表失败：$code');
    }
    final conversationList = mapData['conversationList'];
    if (conversationList is! List) {
      throw const FormatException('会话列表数据格式错误');
    }
    return conversationList
        .whereType<Map>()
        .map(
          (item) => ConversationModel.formJSON(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  } on DioException catch (e) {
    debugPrint('POST请求失败：${e.error}');
    rethrow;
  } catch (e) {
    debugPrint('获取会话列表失败：$e');
    rethrow;
  }
}
