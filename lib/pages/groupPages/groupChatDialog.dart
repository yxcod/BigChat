import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/gloabl.dart';
import '../../model/groupMemberModel.dart';
import '../../model/groupInfoModel.dart';
import '../../utils/WebSocketManager.dart';
import '../../model/messageModel.dart';
import '../../model/groupMessageModel.dart';
import '../videoCallPage.dart';
import '../../utils/http.dart';
import '../../api/getGroupInfoAPI.dart';
import '../../api/getGroupMemberAPI.dart';
import '../../api/groupChatRecordAPI.dart';
import '../../utils/user_profile_navigator.dart';
import '../../features/chat/domain/chat_message_mapper.dart';

class GroupChatDialogPage extends StatefulWidget {
  final int groupId;
  final String groupName;

  GroupChatDialogPage({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  _GroupChatDialogPageState createState() => _GroupChatDialogPageState();
}

class _GroupChatDialogPageState extends State<GroupChatDialogPage> {
  WebSocketManager _wsManager = WebSocketManager();
  WebSocketMessageSubscription? _messageSubscription;
  WebSocketStatusSubscription? _statusSubscription;
  FocusNode _textFieldFocusNode = FocusNode();
  ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  List<Map<String, dynamic>> _messageReadStatus = []; // 存储每条消息的已读状态
  final Set<int> _sentReadAckMessageIds = {};
  int _loadedMessageLimit = 100;
  late Timer _groupInfoTimer; // 定时器，用于定期获取群信息
  late Timer _groupMembersTimer; // 定时器，用于定期检查群成员列表
  String _currentGroupName = ''; // 当前显示的群名称

  @override
  void initState() {
    super.initState();

    // 初始化群名称
    _currentGroupName = widget.groupName;

    // 为滚动控制器添加监听器，实现向上滑动加载更多
    _scrollController.addListener(() {
      final atTop =
          _scrollController.position.pixels <=
          _scrollController.position.minScrollExtent + 5.0;

      if (atTop) {
        _loadMoreChatRecords();
      }
    });

    // 初始化WebSocket连接
    _ensureWebSocketConnected();

    // WebSocket 暂未推送群资料变更，使用低频刷新作为兜底。
    _groupInfoTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchGroupInfo();
    });

    // 先加载群成员，再加载带已读状态的群聊记录。
    _initializeGroupChatData();

    _groupMembersTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkGroupMembership();
    });

    // 页面初始化时自动滚动到聊天记录底部
    _scrollToBottom();
  }

  Future<void> _initializeGroupChatData() async {
    final restored = await GlobalUtil().hydrateChatRecords(
      widget.groupId.toString(),
    );
    if (restored && mounted) {
      setState(() {});
      _scrollToBottom();
    }
    await _checkGroupMembership();
    if (!mounted) {
      return;
    }
    await _loadGroupChatRecords(limit: _loadedMessageLimit);
  }

  int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _loadGroupChatRecords({
    required int limit,
    bool scrollToBottom = true,
  }) async {
    try {
      final groupRecord = await getGroupChatRecord(widget.groupId, limit);
      final globalUtil = GlobalUtil();
      final currentUserId = globalUtil.userName ?? '';
      final existingMessages = List<Message>.from(
        globalUtil.getChatRecords(widget.groupId.toString()),
      );
      final existingById = {
        for (final message in existingMessages) message.msgId: message,
      };

      final messages = groupRecord.messages
          .map(
            (record) => ChatMessageMapper.fromGroupRecord(
              record,
              currentUserId: currentUserId,
              conversationId: widget.groupId.toString(),
            ),
          )
          .toList();

      final loadedMessageIds = messages.map((message) => message.msgId).toSet();
      for (final entry in existingById.entries) {
        if (!loadedMessageIds.contains(entry.key)) {
          messages.add(entry.value);
        }
      }
      messages.sort((left, right) => left.msgId.compareTo(right.msgId));

      await globalUtil.replaceChatRecords(widget.groupId.toString(), messages);

      _replaceReadStatuses(groupRecord.messages);
      _loadedMessageLimit = limit;

      if (mounted) {
        setState(() {});
        if (scrollToBottom) {
          _scrollToBottom();
        }
      }
      _sendReadAcksForLoadedMessages();
    } catch (e) {
      debugPrint('加载群聊记录及已读状态失败: $e');
    }
  }

  void _replaceReadStatuses(List<MessageDetailModel> records) {
    final members = GlobalUtil().getGroupMembers(widget.groupId);
    final previousStatuses = {
      for (final status in _messageReadStatus) status['msgId'] as int: status,
    };
    final newStatuses = <Map<String, dynamic>>[];

    for (final record in records) {
      final readUserIds = record.readers
          .map((reader) => reader.userId)
          .where((userId) => userId.isNotEmpty)
          .toSet();
      final readTimes = <String, int>{
        for (final reader in record.readers)
          if (reader.userId.isNotEmpty) reader.userId: reader.readTime,
      };
      final backendUnreadUserIds = record.unreaders
          .map((reader) => reader.userId)
          .where((userId) => userId.isNotEmpty)
          .toSet();
      final eligibleMemberIds = members
          .where(
            (member) =>
                member.userId.isNotEmpty && member.userId != record.senderId,
          )
          .map((member) => member.userId)
          .toSet();
      final backendStatusUserIds = <String>{
        ...readUserIds,
        ...backendUnreadUserIds,
      };
      final hasCompleteServerReadState =
          record.hasUnreadersField &&
          eligibleMemberIds.difference(backendStatusUserIds).isEmpty;

      // 老消息可能没有初始化阅读记录，此时按当前群成员补算，避免显示虚假的 0 人未读。
      final unreadUserIds = hasCompleteServerReadState
          ? backendUnreadUserIds
          : eligibleMemberIds.difference(readUserIds);

      newStatuses.add({
        'msgId': record.msgId,
        'readCount': readUserIds.length,
        'unreadCount': unreadUserIds.length,
        'readMembers': readUserIds.toList(),
        'unreadMembers': unreadUserIds.toList(),
        'readTimes': readTimes,
        'hasCompleteServerReadState': hasCompleteServerReadState,
      });
      previousStatuses.remove(record.msgId);
    }

    newStatuses.addAll(previousStatuses.values);
    _messageReadStatus = newStatuses;
  }

  void _initializeOutgoingReadStatus(int msgId) {
    final currentUserId = GlobalUtil().userName;
    final unreadUserIds = GlobalUtil()
        .getGroupMembers(widget.groupId)
        .where(
          (member) =>
              member.userId.isNotEmpty && member.userId != currentUserId,
        )
        .map((member) => member.userId)
        .toSet()
        .toList();

    _messageReadStatus.removeWhere((status) => status['msgId'] == msgId);
    _messageReadStatus.add({
      'msgId': msgId,
      'readCount': 0,
      'unreadCount': unreadUserIds.length,
      'readMembers': <String>[],
      'unreadMembers': unreadUserIds,
      'readTimes': <String, int>{},
      'hasCompleteServerReadState': false,
    });
  }

  void _reconcileIncompleteReadStatuses() {
    final globalUtil = GlobalUtil();
    final currentUserId = globalUtil.userName;
    final eligibleMemberIds = globalUtil
        .getGroupMembers(widget.groupId)
        .where(
          (member) =>
              member.userId.isNotEmpty && member.userId != currentUserId,
        )
        .map((member) => member.userId)
        .toSet();
    final ownMessageIds = globalUtil
        .getChatRecords(widget.groupId.toString())
        .where((message) => message.isMe)
        .map((message) => message.msgId)
        .toSet();

    for (var index = 0; index < _messageReadStatus.length; index++) {
      final status = _messageReadStatus[index];
      final msgId = _parseInt(status['msgId']);
      if (!ownMessageIds.contains(msgId) ||
          status['hasCompleteServerReadState'] == true) {
        continue;
      }
      final readMembers = List<String>.from(
        status['readMembers'] ?? const [],
      ).toSet();
      final unreadMembers = eligibleMemberIds.difference(readMembers).toList();
      _messageReadStatus[index] = {
        ...status,
        'readCount': readMembers.length,
        'unreadCount': unreadMembers.length,
        'readMembers': readMembers.toList(),
        'unreadMembers': unreadMembers,
      };
    }
  }

  void _sendReadAcksForLoadedMessages() {
    if (!_wsManager.isConnected) {
      return;
    }
    final globalUtil = GlobalUtil();
    final currentUserId = globalUtil.userName;
    if (currentUserId == null || currentUserId.isEmpty) {
      return;
    }

    for (final message in globalUtil.getChatRecords(
      widget.groupId.toString(),
    )) {
      if (message.isMe ||
          message.senderId == null ||
          message.senderId!.isEmpty) {
        continue;
      }
      final statusIndex = _messageReadStatus.indexWhere(
        (status) => status['msgId'] == message.msgId,
      );
      final readMembers = statusIndex == -1
          ? <String>[]
          : List<String>.from(
              _messageReadStatus[statusIndex]['readMembers'] ?? const [],
            );
      if (!readMembers.contains(currentUserId) &&
          _sentReadAckMessageIds.add(message.msgId)) {
        _sendReadAck(message.msgId, message.senderId!);
      }
    }
  }

  // 获取群信息
  Future<void> _fetchGroupInfo() async {
    try {
      final globalUtil = GlobalUtil();
      String? userName = globalUtil.userName;
      if (userName == null) {
        return;
      }

      // 调用API获取用户的所有群信息
      List<GroupInfoModel> groups = await getGroups(userName);

      // 找到当前群
      for (var group in groups) {
        if (group.groupId == widget.groupId) {
          // 检查群名称是否有变化
          if (group.groupName != _currentGroupName) {
            setState(() {
              _currentGroupName = group.groupName;
            });
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('获取群信息失败: $e');
    }
  }

  // 加载更多聊天记录
  Future<void> _loadMoreChatRecords() async {
    if (_isLoadingMore) {
      return;
    }

    try {
      _isLoadingMore = true;
      final globalUtil = GlobalUtil();

      // 记录当前聊天记录
      List<Message> currentMessages = List.from(
        globalUtil.getChatRecords(widget.groupId.toString()),
      );

      // 记录当前可见区域的关键消息
      Message? keyMessage;
      if (_scrollController.hasClients && currentMessages.isNotEmpty) {
        final scrollPosition = _scrollController.position.pixels;
        final averageItemHeight = scrollPosition > 0
            ? scrollPosition / currentMessages.length
            : 50.0;

        int middleIndex =
            (scrollPosition +
                _scrollController.position.viewportDimension / 2) ~/
            averageItemHeight;
        middleIndex = middleIndex.clamp(0, currentMessages.length - 1);
        keyMessage = currentMessages[middleIndex];
      }

      // 群聊必须使用群聊记录接口，不能复用单聊记录接口。
      await _loadGroupChatRecords(
        limit: currentMessages.length + 100,
        scrollToBottom: false,
      );

      // 获取新的聊天记录列表
      List<Message> newMessages = globalUtil.getChatRecords(
        widget.groupId.toString(),
      );

      // 更新UI
      setState(() {});

      // 使用SchedulerBinding确保在UI更新完成后再调整滚动位置
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && keyMessage != null) {
          // 找到关键消息在新列表中的位置
          int newIndex = newMessages.indexWhere(
            (msg) => msg.msgId == keyMessage!.msgId,
          );

          if (newIndex != -1) {
            final position = _scrollController.position;
            double averageItemHeight = 0;
            if (newMessages.isNotEmpty) {
              averageItemHeight = position.maxScrollExtent / newMessages.length;
            }

            // 计算关键消息在旧列表中的位置
            int oldIndex = currentMessages.indexOf(keyMessage);

            if (oldIndex != -1) {
              int indexDifference = newIndex - oldIndex;
              final newScrollOffset =
                  _scrollController.position.pixels +
                  (indexDifference * averageItemHeight);

              final safeOffset = newScrollOffset.clamp(
                0.0,
                position.maxScrollExtent,
              );

              _scrollController.jumpTo(safeOffset);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('加载更多聊天记录失败: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  // 发送图片消息
  Future<void> _sendImageMessage(File imageFile) async {
    try {
      final globalUtil = GlobalUtil();

      // 获取当前时间和消息ID
      String time = _getTime();
      int msgId = DateTime.now().millisecondsSinceEpoch;
      String conversationId = widget.groupId.toString();

      // 生成图片文件名
      String imageName = '${globalUtil.userName}_${widget.groupId}_$msgId.jpg';
      // 上传图片到服务器
      await _uploadImage(imageFile, imageName);
      // 创建消息对象
      Message newMessage = Message(
        msgId: msgId,
        content: imageName,
        isMe: true,
        time: time,
        isRead: false,
        conversationId: conversationId,
        messageType: MessageType.image,
        status: MessageStatus.failed,
        senderId: globalUtil.userName,
      );

      // 添加消息到全局聊天记录
      globalUtil.addMessage(widget.groupId.toString(), newMessage);
      _initializeOutgoingReadStatus(msgId);

      // 更新UI并滚动到底部
      setState(() {});
      _scrollToBottom();

      // 使用WebSocket发送消息
      if (_wsManager.isConnected) {
        // 构建并发送WebSocket消息
        _sendWebSocketMessage(
          msgId: msgId,
          content: imageName,
          receiver: widget.groupId,
          conversationId: conversationId,
          messageType: MessageType.image,
        );

        // 更新消息状态为发送中
        List<Message> groupMessages = globalUtil.getChatRecords(
          widget.groupId.toString(),
        );
        for (var message in groupMessages) {
          if (message.msgId == msgId && message.isMe) {
            message.status = MessageStatus.sent;
            break;
          }
        }

        // 更新UI并滚动到底部
        setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('发送图片消息失败: $e');
    }
  }

  // 上传图片到服务器
  Future<void> _uploadImage(File imageFile, String imageName) async {
    try {
      final httpUtil = HttpUtil();

      // 将File转换为Uint8List
      Uint8List imageData = await imageFile.readAsBytes();

      // 调用HttpUtil的uploadImage接口
      await httpUtil.uploadImage(imageName, imageData);

      debugPrint('Image uploaded successfully');
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  // 选择图片
  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        _sendImageMessage(imageFile);
      }
    } catch (e) {
      debugPrint('选择图片失败: $e');
    }
  }

  // 处理WebSocket消息
  void _handleWebSocketMessage(dynamic message) {
    debugPrint('=== 收到WebSocket消息 ===');
    debugPrint('原始消息: $message');
    debugPrint('消息运行时类型: ${message.runtimeType}');

    // 处理不同类型的消息格式
    dynamic parsedMessage;
    if (message is String) {
      debugPrint('消息是字符串类型，尝试解析为JSON');
      try {
        parsedMessage = json.decode(message);
        debugPrint('JSON解析成功: $parsedMessage');
      } catch (e) {
        debugPrint('JSON解析失败: $e');
        return;
      }
    } else if (message is Map) {
      debugPrint('消息是Map类型');
      parsedMessage = message;
    } else {
      debugPrint('未知消息类型: ${message.runtimeType}');
      return;
    }

    // 确保消息是Map<String, dynamic>类型
    if (parsedMessage is Map<String, dynamic>) {
      String messageType = parsedMessage['type'] ?? '';
      debugPrint('消息类型: $messageType');

      switch (messageType) {
        case 'groupChat':
          debugPrint('处理群聊消息...');
          _handleChatMessage(parsedMessage);
          break;
        case 'groupChatCallback':
          debugPrint('处理群聊回调...');
          _handleChatCallback(parsedMessage);
          break;
        case 'videoCallInvite':
          _handleVideoCallInvite(parsedMessage);
          break;
        case 'videoCallAccept':
          _handleVideoCallAccept(parsedMessage);
          break;
        case 'videoCallReject':
          _handleVideoCallReject(parsedMessage);
          break;
        case 'videoCallHangup':
          _handleVideoCallHangup(parsedMessage);
          break;
        default:
          debugPrint('未知消息类型: $messageType');
      }
    } else {
      debugPrint(
        '消息格式不正确，不是Map<String, dynamic>类型: ${parsedMessage.runtimeType}',
      );
    }
  }

  // 处理聊天消息
  void _handleChatMessage(Map<String, dynamic> messageData) {
    final globalUtil = GlobalUtil();

    // 添加调试日志，打印接收到的完整消息数据
    debugPrint('=== 收到群聊消息 ===');
    debugPrint('消息数据: $messageData');
    debugPrint('当前群ID: ${widget.groupId}');
    debugPrint('当前用户: ${globalUtil.userName}');

    String sender = messageData['sendUserId']?.toString() ?? '';
    String content = messageData['msgContent']?.toString() ?? '';
    int msgId = _parseInt(messageData['msgId']);
    int msgType = _parseInt(messageData['msgType'], fallback: 1);
    int receiveId = _parseInt(messageData['receiveId']);
    int receiveType = _parseInt(messageData['receiveType'], fallback: 2);

    // 处理时间戳，支持多种格式
    var rawSendTime = messageData['sendTime'];
    int timestamp = 0;
    if (rawSendTime is int) {
      timestamp = rawSendTime;
    } else if (rawSendTime is String) {
      timestamp = int.tryParse(rawSendTime) ?? 0;
    }
    String sendTime = _formatTimestamp(timestamp);

    debugPrint('解析后的数据:');
    debugPrint('  发送者: $sender');
    debugPrint('  内容: $content');
    debugPrint('  消息ID: $msgId');
    debugPrint('  接收者ID: $receiveId');
    debugPrint('  接收类型: $receiveType');
    debugPrint('  时间戳: $timestamp');

    // 检查消息是否属于当前群聊
    if (receiveId != widget.groupId) {
      debugPrint('消息不属于当前群聊，忽略。消息接收者: $receiveId, 当前群ID: ${widget.groupId}');
      return;
    }

    if (sender.isNotEmpty && content.isNotEmpty) {
      // 检查消息是否已存在
      List<Message> existingMessages = globalUtil.getChatRecords(
        widget.groupId.toString(),
      );
      bool messageExists = existingMessages.any((msg) => msg.msgId == msgId);

      debugPrint('消息是否已存在: $messageExists');
      debugPrint('现有消息数量: ${existingMessages.length}');

      if (!messageExists) {
        // 创建新消息
        Message newMessage = Message(
          msgId: msgId,
          content: content,
          isMe: sender == globalUtil.userName,
          time: sendTime,
          isRead: false,
          conversationId: widget.groupId.toString(),
          messageType: msgType == 2 ? MessageType.image : MessageType.text,
          status: MessageStatus.sent,
          senderId: sender,
        );

        debugPrint(
          '创建新消息: msgId=$msgId, isMe=${sender == globalUtil.userName}, sender=$sender',
        );

        // 添加消息到全局聊天记录
        globalUtil.addMessage(widget.groupId.toString(), newMessage);

        debugPrint('消息已添加到聊天记录');

        // 更新UI并滚动到底部
        if (mounted) {
          setState(() {});
          _scrollToBottom();
          debugPrint('UI已更新');
        }

        // 发送已读确认（只发送给发送者，不发送给自己发的消息）
        if (sender != globalUtil.userName) {
          _sentReadAckMessageIds.add(msgId);
          _sendReadAck(msgId, sender);
        }
      }
    } else {
      debugPrint('消息数据无效: sender=$sender, content=$content');
    }
  }

  // 处理聊天确认回调
  void _handleChatCallback(Map<String, dynamic> messageData) {
    final globalUtil = GlobalUtil();
    int msgId = _parseInt(messageData['msgId']);
    String status = messageData['status']?.toString() ?? '';
    String sender = messageData['sender']?.toString() ?? '';
    String sessionId = messageData['sessionId']?.toString() ?? '';
    int readTime = _parseInt(
      messageData['readTime'],
      fallback: DateTime.now().millisecondsSinceEpoch,
    );
    if (sessionId != widget.groupId.toString()) {
      return;
    }

    // 更新消息状态
    List<Message> groupMessages = globalUtil.getChatRecords(
      widget.groupId.toString(),
    );
    for (var message in groupMessages) {
      if (message.msgId == msgId) {
        if (status == 'success' && message.isMe) {
          message.status = MessageStatus.sent;
        } else if (status == 'failed' && message.isMe) {
          message.status = MessageStatus.failed;
        } else if (status == 'read' && message.isMe) {
          // 更新消息已读状态
          message.isRead = true;
          // 更新消息的已读人数
          _updateMessageReadStatus(msgId, sender, readTime);
        }
        break;
      }
    }

    // 更新UI
    if (mounted) {
      setState(() {});
    }
  }

  // 更新消息的已读状态
  void _updateMessageReadStatus(int msgId, String reader, int readTime) {
    var msgStatusIndex = _messageReadStatus.indexWhere(
      (status) => status['msgId'] == msgId,
    );
    if (msgStatusIndex == -1) {
      _initializeOutgoingReadStatus(msgId);
      msgStatusIndex = _messageReadStatus.indexWhere(
        (status) => status['msgId'] == msgId,
      );
    }
    if (msgStatusIndex == -1 || reader.isEmpty) {
      return;
    }

    final msgStatus = _messageReadStatus[msgStatusIndex];
    final readMembers = List<String>.from(msgStatus['readMembers'] ?? const []);
    final unreadMembers = List<String>.from(
      msgStatus['unreadMembers'] ?? const [],
    );
    final readTimes = Map<String, int>.from(
      msgStatus['readTimes'] ?? const <String, int>{},
    );

    if (!readMembers.contains(reader)) {
      readMembers.add(reader);
      unreadMembers.remove(reader);
    }
    readTimes[reader] = readTime;
    _messageReadStatus[msgStatusIndex] = {
      ...msgStatus,
      'readMembers': readMembers,
      'unreadMembers': unreadMembers,
      'readTimes': readTimes,
      'readCount': readMembers.length,
      'unreadCount': unreadMembers.length,
    };
  }

  // 处理视频通话邀请
  void _handleVideoCallInvite(Map<String, dynamic> messageData) {
    // 视频通话邀请处理逻辑
  }

  // 处理视频通话接受
  void _handleVideoCallAccept(Map<String, dynamic> messageData) {
    // 视频通话接受处理逻辑
  }

  // 处理视频通话拒绝
  void _handleVideoCallReject(Map<String, dynamic> messageData) {
    // 获取拒绝者信息
    String sender = messageData['sender'] ?? '';

    if (sender.isNotEmpty) {
      // 显示拒绝通知
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$sender 拒绝了您的视频通话邀请'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // 处理视频通话挂断
  void _handleVideoCallHangup(Map<String, dynamic> messageData) {
    // 视频通话挂断处理逻辑
  }

  // 发送已读确认
  void _sendReadAck(int msgId, String receiveId) {
    if (_wsManager.isConnected) {
      _wsManager.send({
        'type': 'groupChatCallback',
        'msgId': msgId,
        'receiveId': receiveId,
        'sender': GlobalUtil().userName,
        'sessionId': widget.groupId.toString(),
        'status': 'read',
      });
    }
  }

  // 确保WebSocket已连接
  void _ensureWebSocketConnected() {
    _messageSubscription?.cancel();
    _messageSubscription = _wsManager.addMessageListener(
      _handleWebSocketMessage,
    );
    _statusSubscription?.cancel();
    _statusSubscription = _wsManager.addStatusListener((status) {
      debugPrint('WebSocket状态: $status');
      if (status == WebSocketStatus.connected) {
        _sendReadAcksForLoadedMessages();
      }
    });

    // 确保WebSocket连接已建立
    if (!_wsManager.isConnected) {
      _wsManager.connect(
        GlobalUtil().getChatWebSocketURL(GlobalUtil().userName ?? ''),
      );
    } else {
      debugPrint('WebSocket已连接，只更新监听器');
      _sendReadAcksForLoadedMessages();
    }
  }

  // 滚动到底部的辅助方法
  void _scrollToBottom() {
    if (GlobalUtil().getChatRecords(widget.groupId.toString()).isNotEmpty) {
      // 使用SchedulerBinding确保在适当的时间执行滚动
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // 首次跳转到底部
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);

          // 设置一个短暂延迟后再次跳转，确保图片加载完成后的高度被计算
          Future.delayed(Duration(milliseconds: 300), () {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          });

          // 0.6秒后再次滚动，确保所有图片都加载完成
          Future.delayed(Duration(milliseconds: 600), () {
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
            }
          });
        }
      });
    }
  }

  // 检查用户是否在群成员列表中
  Future<void> _checkGroupMembership() async {
    try {
      // 导入getGroupMemberAPI.dart中的getGroupMembers函数
      List<GroupMemberModel> members = await getGroupMembers(widget.groupId);

      // 更新全局群成员列表
      final globalUtil = GlobalUtil();
      globalUtil.addGroupMembers(widget.groupId, members);
      _reconcileIncompleteReadStatuses();

      // 触发UI重建，确保聊天记录显示最新的群成员信息（头像和昵称）
      if (mounted) {
        setState(() {});
      }

      // 遍历群成员列表，检查当前用户是否在列表中
      String? currentUserId = globalUtil.userName;
      bool foundUser = false;

      for (var member in members) {
        if (currentUserId != null && member.userId == currentUserId) {
          foundUser = true;
          break;
        }
      }

      if (!foundUser) {
        debugPrint('未找到当前用户在群成员列表中');
        // 停止所有定时器，防止重复触发
        _groupInfoTimer.cancel();
        _groupMembersTimer.cancel();
        // 用户不在群成员列表中，说明已被移除出群聊
        if (mounted) {
          // 导航到主界面并传递被移除群聊的信号，同时清除导航栈
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/mainWidget',
            (route) => false, // 清除所有路由，使mainWidget成为根页面
            arguments: {'isRemovedFromGroup': true},
          );
        }
      }
    } catch (e) {
      debugPrint('检查群成员列表失败: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFieldFocusNode.dispose();
    _scrollController.dispose();

    // 取消定时器
    _groupInfoTimer.cancel();
    _groupMembersTimer.cancel();

    // 移除本页面自己的消息订阅，不影响其他页面。
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    debugPrint('群聊页面销毁，已移除WebSocket监听器');

    // 离开聊天页面时，更新全局聊天状态
    final globalUtil = GlobalUtil();
    globalUtil.isChatting = false;
    globalUtil.currentChatUserName = null;

    super.dispose();
  }

  final TextEditingController _textController = TextEditingController();
  bool _isComposing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Center(
          child: Text(
            _currentGroupName,
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.videocam, color: Colors.black),
            onPressed: () {
              // 发起群视频通话
              const token = ''; // 可以使用Agora控制台生成的临时token

              // 发送视频通话邀请
              if (_wsManager.isConnected) {
                _wsManager.send({
                  'type': 'groupVideoCallInvite',
                  'receiver': widget.groupId,
                  'sender': GlobalUtil().userName,
                  'channelName': widget.groupId.toString(),
                  'token': token,
                  'time': DateTime.now().millisecondsSinceEpoch,
                });
              }

              // 使用groupId作为频道名称
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => VideoCallPage(
                    channelName: widget.groupId.toString(),
                    token: token,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // 进入群聊设置页面
              Navigator.pushNamed(
                context,
                '/groupChatSettings',
                arguments: {
                  'groupId': widget.groupId.toString(),
                  'groupName': _currentGroupName,
                },
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // 点击空白区域隐藏键盘
          FocusScope.of(context).unfocus();
        },
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              //聊天背景图
              image: NetworkImage(
                'https://images.unsplash.com/photo-1518837695005-2083093ee35b?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80',
              ),
              fit: BoxFit.cover,
              opacity: 0.2,
            ),
          ),
          child: Column(
            //聊天气泡
            children: [
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(8.0),
                  reverse: false,
                  controller: _scrollController,
                  // 使用当前聊天群的全局消息列表，如果不存在则使用空列表
                  itemCount: GlobalUtil()
                      .getChatRecords(widget.groupId.toString())
                      .length,
                  itemBuilder: (context, index) {
                    // 获取当前聊天群的全局消息列表
                    final globalUtil = GlobalUtil();
                    final groupMessages = globalUtil.getChatRecords(
                      widget.groupId.toString(),
                    );
                    final message = groupMessages[index];
                    // 获取消息的未读人数
                    int unreadCount = 0; // 默认值
                    final msgStatusIndex = _messageReadStatus.indexWhere(
                      (status) => status['msgId'] == message.msgId,
                    );
                    if (msgStatusIndex != -1) {
                      unreadCount =
                          _messageReadStatus[msgStatusIndex]['unreadCount'] ??
                          unreadCount;
                    }

                    return GroupMessageBubble(
                      message: message,
                      currentUserAvatar: globalUtil.userInfoModel.avatar,
                      onReadStatusTap: () {
                        _showReadStatusList(message.msgId);
                      },
                      unreadCount: unreadCount,
                      groupMembers: globalUtil.getGroupMembers(widget.groupId),
                    );
                  },
                ),
              ),
              Divider(height: 1.0),
              //下方的编辑输入框
              Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor),
                child: _buildTextComposer(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          children: [
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 15),
                margin: EdgeInsets.symmetric(vertical: 4.0),
                child: TextField(
                  controller: _textController,
                  focusNode: _textFieldFocusNode,
                  onChanged: (String text) {
                    setState(() {
                      _isComposing = text.isNotEmpty;
                    });
                  },
                  //监测键盘回车按键自动将当前TextField中的文本内容作为参数传递给 _handleSubmitted
                  onSubmitted: _handleSubmitted,
                  decoration: InputDecoration.collapsed(hintText: '输入消息...'),
                  // 确保点击时可以获取焦点并弹出键盘
                  autofocus: false,
                  // 简化焦点获取逻辑
                  onTap: () {
                    // 请求当前输入框获取焦点
                    _textFieldFocusNode.requestFocus();
                  },
                  // 确保在web端也能正常工作的属性
                  enableInteractiveSelection: true,
                  enableSuggestions: true,
                  autocorrect: true,
                  // 确保输入框可以接收用户输入
                  readOnly: false,
                ),
              ),
            ),
            IconButton(icon: Icon(Icons.attach_file), onPressed: () {}),
            IconButton(icon: Icon(Icons.camera_alt), onPressed: _pickImage),
            IconButton(
              icon: Icon(Icons.send),
              //_isComposing为true时候表示输入框内容不为空才能发送出去
              onPressed: _isComposing
                  ? () => _handleSubmitted(_textController.text)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmitted(String text) {
    _textController.clear();

    // 获取当前时间和消息ID
    String time = _getTime();
    int msgId = DateTime.now().millisecondsSinceEpoch;
    String conversationId = widget.groupId.toString();

    final globalUtil = GlobalUtil();

    setState(() {
      _isComposing = false;
    });

    // 创建消息对象，状态为发送中
    Message newMessage = Message(
      msgId: msgId,
      content: text,
      isMe: true,
      time: time,
      isRead: false,
      conversationId: conversationId,
      messageType: MessageType.text,
      status: MessageStatus.failed, // 初始状态为失败，等待WebSocket确认
      senderId: globalUtil.userName,
    );

    // 添加消息到全局聊天记录
    globalUtil.addMessage(widget.groupId.toString(), newMessage);

    // 新消息默认由除发送者外的当前群成员组成未读名单。
    _initializeOutgoingReadStatus(msgId);

    // 更新UI并滚动到底部
    setState(() {});
    _scrollToBottom();

    // 使用WebSocket发送消息
    if (_wsManager.isConnected) {
      // 构建并发送WebSocket消息
      _sendWebSocketMessage(
        msgId: msgId,
        content: text,
        receiver: widget.groupId,
        conversationId: conversationId,
        messageType: MessageType.text,
      );

      // 更新消息状态为发送中
      List<Message> groupMessages = globalUtil.getChatRecords(
        widget.groupId.toString(),
      );
      for (var message in groupMessages) {
        if (message.msgId == msgId && message.isMe) {
          message.status = MessageStatus.sent;
          break;
        }
      }

      // 更新UI并滚动到底部
      setState(() {});
      _scrollToBottom();
    } else {
      debugPrint('WebSocket未连接,消息发送失败');
      // 保持失败状态
    }
  }

  // 发送WebSocket消息的通用方法
  void _sendWebSocketMessage({
    required int msgId,
    required String content,
    required int receiver,
    required String conversationId,
    required MessageType messageType,
  }) {
    // 根据消息类型设置msgType
    int msgType = messageType == MessageType.image ? 2 : 1;

    // 构建消息数据
    Map<String, dynamic> messageData = {
      'type': 'groupChat',
      'msgType': msgType, // 1文本 2图片
      'msgId': msgId,
      'msgContent': content,
      'sendUserId': GlobalUtil().userName,
      'receiveId': receiver,
      'sendTime': GlobalUtil.getCurrentTimestamp(),
      'readTime': 0,
      'sessionId': conversationId,
      "receiveType": 2, // 2表示群聊
      'extendInfo': "无",
      'msgStatus': 1, //1 发送成功  3 已读
    };

    // 添加调试日志
    debugPrint('=== 发送群聊消息 ===');
    debugPrint('消息数据: $messageData');
    debugPrint('WebSocket连接状态: ${_wsManager.isConnected}');

    // 发送WebSocket消息
    _wsManager.send(messageData);
    debugPrint('消息已发送');
  }

  String _getTime() {
    return GlobalUtil.formatChatTimestamp(
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  // 将时间戳转换为聊天消息时间格式。
  String _formatTimestamp(int timestamp) {
    return GlobalUtil.formatChatTimestamp(timestamp);
  }

  String _formatReadTime(int timestamp) {
    if (timestamp <= 0) {
      return '--:--:--';
    }
    final normalizedTimestamp = timestamp < 1000000000000
        ? timestamp * 1000
        : timestamp;
    final dateTime = DateTime.fromMillisecondsSinceEpoch(normalizedTimestamp);
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  // 显示已读状态列表
  void _showReadStatusList(int msgId) {
    final msgStatus = _messageReadStatus.firstWhere(
      (status) => status['msgId'] == msgId,
      orElse: () => {
        'msgId': msgId,
        'readCount': 0,
        'unreadCount': 0,
        'readMembers': <String>[],
        'unreadMembers': <String>[],
        'readTimes': <String, int>{},
      },
    );
    final readUserIds = List<String>.from(msgStatus['readMembers'] ?? const []);
    final unreadCount = _parseInt(msgStatus['unreadCount']);
    final readTimes = Map<String, int>.from(
      msgStatus['readTimes'] ?? const <String, int>{},
    );
    final membersById = {
      for (final member in GlobalUtil().getGroupMembers(widget.groupId))
        member.userId: member,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '消息阅读情况',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${readUserIds.length}人已读 · $unreadCount人未读',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    '已读人员',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: readUserIds.isEmpty
                        ? Center(
                            child: Text(
                              '暂时还没有人已读',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          )
                        : ListView.separated(
                            itemCount: readUserIds.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, indent: 52),
                            itemBuilder: (context, index) {
                              final userId = readUserIds[index];
                              final member = membersById[userId];
                              final displayName =
                                  member?.groupNickName.trim().isNotEmpty ==
                                      true
                                  ? member!.groupNickName.trim()
                                  : userId;
                              final initial = displayName.isEmpty
                                  ? '?'
                                  : displayName.characters.first;
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(child: Text(initial)),
                                title: Text(displayName),
                                subtitle: displayName == userId
                                    ? null
                                    : Text(userId),
                                trailing: Text(
                                  _formatReadTime(readTimes[userId] ?? 0),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class GroupMessageBubble extends StatelessWidget {
  final Message message;
  final String? currentUserAvatar;
  final VoidCallback onReadStatusTap;
  final int unreadCount;
  final List<GroupMemberModel> groupMembers;
  final globalUtil = GlobalUtil();
  final dio = Dio();
  // 静态缓存自己的头像 URL，用于避免重复加载
  static String? _selfAvatarCache;
  // 缓存自己的头像文件名，用于判断是否需要更新头像
  static String? _selfAvatarNameCache;
  // 静态缓存发送者的头像 URL，使用Map存储，键为发送者ID
  static Map<String, String?> _senderAvatarCache = {};
  // 静态缓存发送者的头像文件名，使用Map存储，键为发送者ID
  static Map<String, String?> _senderAvatarNameCache = {};

  GroupMessageBubble({
    required this.message,
    required this.currentUserAvatar,
    required this.onReadStatusTap,
    required this.unreadCount,
    required this.groupMembers,
  });

  // 获取未读人数
  int _getUnreadCount() {
    return unreadCount;
  }

  // 显示图片操作弹窗
  void _showImageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 保存按钮 - 最上面
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _saveImageToGallery(context);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      '保存',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ),
                ),
              ),
              Divider(height: 1),
              // 删除按钮 - 中间
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteImageMessage(context);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      '删除',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ),
                ),
              ),
              Divider(height: 1),
              // 取消按钮 - 最下面
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    alignment: Alignment.center,
                    child: Text(
                      '取消',
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 删除图片消息
  void _deleteImageMessage(BuildContext context) {
    // 从全局聊天记录中删除消息
    // String receiver = message.isMe
    //     ? '' // 群聊消息不需要指定接收者
    //     : globalUtil.userName ?? '';
    globalUtil.deleteMessage(message.conversationId, message.msgId);
  }

  // 保存图片到相册
  void _saveImageToGallery(BuildContext context) {
    // 保存图片到相册的逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('图片保存功能开发中'), duration: Duration(seconds: 2)),
    );
  }

  // 显示文本上下文菜单
  void _showTextContextMenu(BuildContext context) async {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    // 显示菜单
    final String? result = await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + size.width / 2,
        offset.dy,
        offset.dx + size.width / 2,
        offset.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: const [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('复制'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: const [
              Icon(Icons.delete, size: 18),
              SizedBox(width: 8),
              Text('删除'),
            ],
          ),
        ),
      ],
    );

    // 处理菜单选择
    if (result == 'copy') {
      // 复制文本到剪贴板
      Clipboard.setData(ClipboardData(text: message.content));
    } else if (result == 'delete') {
      // 删除消息
      // String receiver = message.isMe
      //     ? '' // 群聊消息不需要指定接收者
      //     : globalUtil.userName ?? '';
      globalUtil.deleteMessage(message.conversationId, message.msgId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: message.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // 消息发送者昵称
          if (!message.isMe) ...[
            Padding(
              padding: EdgeInsets.only(left: 48.0, bottom: 4.0),
              child: Text(
                _getSenderName(),
                style: TextStyle(fontSize: 12, color: Colors.black),
              ),
            ),
          ],
          // 消息内容
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: message.isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              // 对方头像
              if (!message.isMe) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openSenderProfile(context),
                  child: Container(
                    margin: EdgeInsets.only(right: 8.0),
                    padding: const EdgeInsets.all(2),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: _getSenderAvatar() != null
                          ? NetworkImage(_getSenderAvatar()!)
                          : null,
                      child: _getSenderAvatar() == null
                          ? Text(
                              _getSenderName().characters.first,
                              style: TextStyle(fontSize: 16),
                            )
                          : null,
                    ),
                  ),
                ),
              ],
              // 消息气泡
              GestureDetector(
                onLongPress: message.messageType == MessageType.text
                    ? () => _showTextContextMenu(context)
                    : null,
                child: message.messageType == MessageType.text
                    ? _buildTextBubble(context)
                    : _buildImageBubble(context),
              ),
              // 自己的头像
              if (message.isMe) ...[
                Container(
                  margin: EdgeInsets.only(left: 8.0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: _getSelfAvatar() != null
                        ? NetworkImage(_getSelfAvatar()!)
                        : null,
                    child: _getSelfAvatar() == null
                        ? Text(
                            globalUtil.userName?.substring(0, 1) ?? '?',
                            style: TextStyle(fontSize: 16),
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
          // 消息时间和状态
          Padding(
            padding: EdgeInsets.only(
              top: 4.0,
              right: message.isMe ? 50.0 : 0,
              left: message.isMe ? 0 : 50.0,
            ),
            child: Row(
              mainAxisAlignment: message.isMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Text(
                  message.time,
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (message.isMe) ...[
                  SizedBox(width: 4.0),
                  _buildMessageStatus(),
                ],
              ],
            ),
          ),
          // 未读消息提示
          if (message.isMe) ...[
            GestureDetector(
              onTap: onReadStatusTap,
              child: Padding(
                padding: EdgeInsets.only(top: 4.0, right: 50.0),
                child: Text(
                  '${_getUnreadCount()}人未读', // 显示实际的未读人数
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建文本气泡
  Widget _buildTextBubble(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: message.isMe ? Colors.blue[100] : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: message.isMe ? Radius.circular(16) : Radius.circular(4),
          bottomRight: message.isMe ? Radius.circular(4) : Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        message.content,
        style: TextStyle(color: message.isMe ? Colors.black : Colors.black),
      ),
    );
  }

  // 构建图片气泡
  Widget _buildImageBubble(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImageActions(context),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.6,
          maxHeight: 200,
        ),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.blue[100] : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: message.isMe ? Radius.circular(16) : Radius.circular(4),
            bottomRight: message.isMe
                ? Radius.circular(4)
                : Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: CachedNetworkImage(
          imageUrl: message.content,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 150,
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) => Container(
            width: 150,
            height: 150,
            child: Center(child: Icon(Icons.error)),
          ),
        ),
      ),
    );
  }

  // 构建消息状态
  Widget _buildMessageStatus() {
    switch (message.status) {
      case MessageStatus.sent:
        return Text('已发送', style: TextStyle(fontSize: 10, color: Colors.grey));
      case MessageStatus.failed:
        return Text('发送失败', style: TextStyle(fontSize: 10, color: Colors.red));
      default:
        return SizedBox();
    }
  }

  // 获取发送者名称
  String _getSenderName() {
    if (message.isMe) {
      return globalUtil.userName ?? '我';
    } else {
      // 从消息中获取发送者ID
      String? senderId = message.senderId;
      if (senderId == null) {
        return '群成员';
      }

      // 从群成员列表中查找发送者的群昵称
      for (var member in groupMembers) {
        if (member.userId == senderId) {
          return member.groupNickName.trim().isEmpty
              ? member.userId
              : member.groupNickName.trim();
        }
      }

      // 未找到发送者，返回默认值
      return senderId;
    }
  }

  GroupMemberModel? _getSenderMember() {
    final senderId = message.senderId;
    if (senderId == null || senderId.isEmpty) {
      return null;
    }
    for (final member in groupMembers) {
      if (member.userId == senderId) {
        return member;
      }
    }
    return null;
  }

  void _openSenderProfile(BuildContext context) {
    final senderId = message.senderId;
    if (senderId == null || senderId.isEmpty) {
      return;
    }
    final member = _getSenderMember();
    openUserProfile(
      context,
      userName: senderId,
      fallbackNickname: member?.groupNickName,
      fallbackAvatarName: member?.avatar,
    );
  }

  // 获取发送者头像
  String? _getSenderAvatar() {
    // 从消息中获取发送者ID
    String? senderId = message.senderId;
    if (senderId == null) {
      return null;
    }

    // 从群成员列表中查找发送者的头像文件名
    String? senderAvatarName;
    for (var member in groupMembers) {
      if (member.userId == senderId) {
        senderAvatarName = member.avatar;
        break;
      }
    }

    if (senderAvatarName == null) {
      return null;
    }

    // 检查发送者的头像文件名是否发生变化
    if (_senderAvatarNameCache[senderId] != senderAvatarName) {
      // 头像文件名发生变化，重新获取头像URL
      _senderAvatarNameCache[senderId] = senderAvatarName;
      _senderAvatarCache[senderId] = globalUtil.getImageURL(
        senderId,
        senderAvatarName,
      );
    } else if (_senderAvatarCache[senderId] == null) {
      // 缓存中没有头像URL，获取头像URL
      _senderAvatarCache[senderId] = globalUtil.getImageURL(
        senderId,
        senderAvatarName,
      );
    }

    return _senderAvatarCache[senderId];
  }

  // 获取自己的头像URL，使用缓存机制
  String? _getSelfAvatar() {
    if (globalUtil.userName == null) {
      return null;
    }

    // 获取当前用户的头像文件名
    String avatarName = globalUtil.userInfoModel.avatar ?? 'head.jpg';

    // 检查头像文件名是否发生变化
    if (_selfAvatarNameCache != avatarName) {
      // 头像文件名发生变化，重新获取头像URL
      _selfAvatarNameCache = avatarName;
      _selfAvatarCache = globalUtil.getImageURL(
        globalUtil.userName!,
        avatarName,
      );
    } else if (_selfAvatarCache == null) {
      // 缓存中没有头像URL，获取头像URL
      _selfAvatarCache = globalUtil.getImageURL(
        globalUtil.userName!,
        avatarName,
      );
    }

    return _selfAvatarCache;
  }
}
