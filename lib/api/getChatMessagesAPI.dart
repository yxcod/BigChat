import '../model/messageModel.dart';
import '../utils/http.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

//获取最近指定的聊天记录数
Future<List<MessageModel>> getChatMessagesApi({
  required String conversationId,
  int? count,
}) async {
  try {
    Response response = await HttpUtil().post(
      '/api/chat/chatMessages',
      data: {'conversationId': conversationId, 'limit': count},
    );
    debugPrint('获取最近聊天记录POST成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;
    final messageList = mapData['messageList'] as List<dynamic>;

    // 将JSON数组转换为MessageModel列表
    final messages = messageList.map((item) {
      return MessageModel.fromJSON(item as Map<String, dynamic>);
    }).toList();

    // 按照时间戳升序排序，时间戳小的排在前面，时间戳大的排在后面
    messages.sort((a, b) {
      // 处理时间戳可能为null的情况，将null视为较小的值
      final timeA = a.timestamp ?? 0;
      final timeB = b.timestamp ?? 0;
      return timeA.compareTo(timeB);
    });

    return messages;
  } on DioException catch (e) {
    debugPrint('获取最近聊天记录POST失败：${e.error}');
    // 抛出异常或返回空列表
    throw Exception(e.error);
  }
}

//获取所有发送给userName的未读信息
Future<List<MessageModel>> getUnReadChatMessagesApi({
  required String userName,
}) async {
  try {
    Response response = await HttpUtil().post(
      '/api/chat/unReadMessage',
      data: {'userName': userName},
    );
    //debugPrint('POST请求成功：${response.data}');
    final mapData = response.data as Map<String, dynamic>;
    final messageList = mapData['messageList'] as List<dynamic>;

    // 将JSON数组转换为MessageModel列表
    final messages = messageList.map((item) {
      return MessageModel.fromJSON(item as Map<String, dynamic>);
    }).toList();

    // 按照时间戳升序排序，时间戳小的排在前面，时间戳大的排在后面
    messages.sort((a, b) {
      // 处理时间戳可能为null的情况，将null视为较小的值
      final timeA = a.timestamp ?? 0;
      final timeB = b.timestamp ?? 0;
      return timeA.compareTo(timeB);
    });

    return messages;
  } on DioException catch (e) {
    debugPrint('POST请求失败：${e.error}');
    // 抛出异常或返回空列表
    throw Exception(e.error);
  }
}
