import 'package:flutter/material.dart';
import '../model/messageModel.dart';
import '../utils/WebSocketManager.dart';

// 使用WebSocket发送消息
void sendMessageApi(MessageModel messageModel) {
  WebSocketManager wsManager = WebSocketManager();

  // 检查WebSocket连接状态
  if (!wsManager.isConnected) {
    debugPrint('WebSocket未连接，无法发送消息');
    // 可以选择抛出异常或返回错误信息
    // throw Exception('WebSocket未连接');
    return;
  }

  try {
    // 使用WebSocket发送消息
    wsManager.send(messageModel.toJSON());
    debugPrint('WebSocket消息发送成功：${messageModel.toJSON()}');
  } catch (e) {
    debugPrint('WebSocket消息发送失败：$e');
    // 可以选择抛出异常
    // throw Exception(e);
  }
}

// 注：WebSocket发送消息是异步的，不直接返回服务器响应
// 需要通过WebSocketManager的onMessageReceived回调来处理服务器响应
// 如果需要更接近原API的使用方式，可以考虑添加回调参数
