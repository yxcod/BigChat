import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_base/utils/WebSocketManager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('多个页面可独立订阅和取消 WebSocket 消息', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final serverSocketCompleter = Completer<WebSocket>();
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      serverSocketCompleter.complete(socket);
    });

    final manager = WebSocketManager()..reset();
    final firstMessages = <dynamic>[];
    final secondMessages = <dynamic>[];
    final firstReceived = Completer<void>();
    final secondReceivedTwice = Completer<void>();
    final firstSubscription = manager.addMessageListener((message) {
      firstMessages.add(message);
      if (!firstReceived.isCompleted) {
        firstReceived.complete();
      }
    });
    final secondSubscription = manager.addMessageListener((message) {
      secondMessages.add(message);
      if (secondMessages.length == 2 && !secondReceivedTwice.isCompleted) {
        secondReceivedTwice.complete();
      }
    });

    await manager.connect(
      'ws://${server.address.address}:${server.port}',
      heartbeatInterval: const Duration(hours: 1),
      maxReconnectAttempts: 0,
    );
    final serverSocket = await serverSocketCompleter.future;

    serverSocket.add(jsonEncode({'type': 'test', 'value': 1}));
    await firstReceived.future.timeout(const Duration(seconds: 2));
    expect(firstMessages, hasLength(1));
    expect(secondMessages, hasLength(1));

    firstSubscription.cancel();
    serverSocket.add(jsonEncode({'type': 'test', 'value': 2}));
    await secondReceivedTwice.future.timeout(const Duration(seconds: 2));
    expect(firstMessages, hasLength(1));
    expect(secondMessages, hasLength(2));

    secondSubscription.cancel();
    manager.disconnect();
    await serverSocket.close();
    await server.close(force: true);
  });
}
