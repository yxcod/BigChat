import 'package:flutter/material.dart';
import '../utils/WebSocketManager.dart';

class WebSocketExample extends StatefulWidget {
  const WebSocketExample({Key? key}) : super(key: key);

  @override
  State<WebSocketExample> createState() => _WebSocketExampleState();
}

class _WebSocketExampleState extends State<WebSocketExample> {
  final WebSocketManager _wsManager = WebSocketManager();
  final TextEditingController _messageController = TextEditingController();
  WebSocketStatus _status = WebSocketStatus.disconnected;
  List<String> _messages = [];
  String _wsUrl = 'ws://your-websocket-server-url';

  @override
  void initState() {
    super.initState();
    _connectToWebSocket();
  }

  @override
  void dispose() {
    _wsManager.disconnect();
    _messageController.dispose();
    super.dispose();
  }

  void _connectToWebSocket() {
    _wsManager.connect(
      _wsUrl,
      onStatusChanged: (status) {
        setState(() {
          _status = status;
          _addMessage('Status changed: ${status.name}');
        });
      },
      onMessageReceived: (message) {
        setState(() {
          _addMessage('Received: $message');
        });
      },
      onError: (error) {
        setState(() {
          _addMessage('Error: $error');
        });
      },
      heartbeatInterval: const Duration(seconds: 30),
      maxReconnectAttempts: 5,
      reconnectDelay: const Duration(seconds: 2),
    );
  }

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      final message = _messageController.text;
      _wsManager.send({
        'type': 'message',
        'content': message,
        'timestamp': DateTime.now().toIso8601String(),
      });
      _addMessage('Sent: $message');
      _messageController.clear();
    }
  }

  void _disconnect() {
    _wsManager.disconnect();
  }

  void _addMessage(String message) {
    _messages.add(message);
    // 只保留最近50条消息
    if (_messages.length > 50) {
      _messages.removeAt(0);
    }
  }

  Color _getStatusColor(WebSocketStatus status) {
    switch (status) {
      case WebSocketStatus.disconnected:
        return Colors.red;
      case WebSocketStatus.connecting:
      case WebSocketStatus.reconnecting:
        return Colors.orange;
      case WebSocketStatus.connected:
        return Colors.green;
      case WebSocketStatus.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket Example'),
        actions: [
          IconButton(
            icon: Icon(
              _wsManager.isConnected ? Icons.close : Icons.refresh,
              color: Colors.white,
            ),
            onPressed: _wsManager.isConnected
                ? _disconnect
                : _connectToWebSocket,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 连接状态
            Row(
              children: [
                const Text('Connection Status: '),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _status.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 消息列表
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(_messages[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 消息输入和发送
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: 'Enter message',
                      border: const OutlineInputBorder(),
                      hintText: 'Type your message here',
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _wsManager.isConnected ? _sendMessage : null,
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
