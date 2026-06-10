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
    final conversationList = mapData['conversationList'] as List<dynamic>?;
    if (conversationList != null) {
      return conversationList
          .map(
            (item) => ConversationModel.formJSON(item as Map<String, dynamic>),
          )
          .toList();
    } else {
      // 未获取到conversationList数据，返回空列表
      debugPrint('未获取到会话列表数据');
      return [];
    }
  } on DioException catch (e) {
    // 发生DioException异常，返回空列表
    debugPrint('POST请求失败：${e.error}');
    return [];
  } catch (e) {
    // 发生其他异常，返回空列表
    debugPrint('获取会话列表失败：$e');
    return [];
  }
}
