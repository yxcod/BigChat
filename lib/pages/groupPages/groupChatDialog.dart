import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
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
import '../../shared/widgets/app_back_button.dart';
import '../../api/getGroupMemberAPI.dart';
import '../../api/groupChatRecordAPI.dart';
import '../../utils/user_profile_navigator.dart';
import '../../features/chat/domain/chat_message_mapper.dart';
import '../../core/cache/app_image_cache.dart';
import '../../core/config/refresh_intervals.dart';
import '../../core/media/app_media_url.dart';
import '../../shared/widgets/fullscreen_image_viewer.dart';
import '../../shared/utils/chat_scroll_util.dart';
import '../../shared/widgets/chat_background.dart';
import '../../features/groups/presentation/group_route_registry.dart';
import '../../core/media/video_media.dart';
import '../../shared/widgets/app_video_player.dart';
import '../../shared/widgets/app_voice_message.dart';
import '../../shared/widgets/hold_to_record_field.dart';
import '../../shared/widgets/top_aligned_reversed_list.dart';
import '../../core/media/voice_message.dart';

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
  String get _conversationKey =>
      GlobalUtil.groupConversationKey(widget.groupId);
  WebSocketManager _wsManager = WebSocketManager();
  WebSocketMessageSubscription? _messageSubscription;
  WebSocketStatusSubscription? _statusSubscription;
  FocusNode _textFieldFocusNode = FocusNode();
  ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _isInitialScrollPending = true;
  bool _initialPositioningRequested = false;
  int _scrollToBottomRequest = 0;
  bool _isUploadingImage = false;
  bool _isUploadingVideo = false;
  double _videoUploadProgress = 0;
  CancelToken? _imageUploadCancelToken;
  CancelToken? _videoUploadCancelToken;
  final Map<int, String> _localVideoPaths = {};
  final Map<int, double> _videoMessageProgress = {};
  final Set<int> _failedVideoMessageIds = {};
  CancelToken? _audioUploadCancelToken;
  bool _isUploadingAudio = false;
  List<Map<String, dynamic>> _messageReadStatus = []; // 存储每条消息的已读状态
  final Set<int> _sentReadAckMessageIds = {};
  int _loadedMessageLimit = 100;
  late Timer _groupInfoTimer; // 定时器，用于定期获取群信息
  late Timer _groupMembersTimer; // 定时器，用于定期检查群成员列表
  String _currentGroupName = ''; // 当前显示的群名称
  bool _isHandlingHistoryDeletion = false;

  @override
  void initState() {
    super.initState();
    GroupRouteRegistry.enter(widget.groupId);
    final globalUtil = GlobalUtil();
    globalUtil.isChatting = true;
    globalUtil.currentChatUserName = _conversationKey;
    globalUtil.clearUnreadMessages(_conversationKey);
    // isMe 属于当前账号的视图状态，不能直接信任上一个登录账号留下的缓存。
    unawaited(_normalizeCachedMessageOwnership());

    // 初始化群名称
    _currentGroupName = widget.groupName;

    // 为滚动控制器添加监听器，实现向上滑动加载更多
    _scrollController.addListener(() {
      final atTop =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 5.0;

      if (atTop && !_isInitialScrollPending) {
        _loadMoreChatRecords();
      }
    });

    // 初始化WebSocket连接
    _ensureWebSocketConnected();

    // WebSocket 暂未推送群资料变更，使用低频刷新作为兜底。
    _groupInfoTimer = Timer.periodic(
      RefreshIntervals.groupFallback,
      (timer) => _fetchGroupInfo(),
    );

    // 先加载群成员，再加载带已读状态的群聊记录。
    _initializeGroupChatData();

    _groupMembersTimer = Timer.periodic(
      RefreshIntervals.groupFallback,
      (timer) => _checkGroupMembership(),
    );
  }

  Future<void> _initializeGroupChatData() async {
    final restored = await GlobalUtil().hydrateChatRecords(_conversationKey);
    if (restored) {
      await _normalizeCachedMessageOwnership();
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    }
    await _checkGroupMembership();
    if (!mounted) {
      return;
    }
    await _loadGroupChatRecords(
      limit: _loadedMessageLimit,
      scrollToBottom: false,
    );
    if (mounted) {
      _scrollToBottom(completeInitialPositioning: true);
    }
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
        globalUtil.getChatRecords(_conversationKey),
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
      // 服务端明确返回空列表时必须覆盖旧缓存，避免其他设备删除记录后
      // 本机在下次进入群聊时又把历史消息恢复出来。
      if (groupRecord.messages.isNotEmpty) {
        for (final entry in existingById.entries) {
          if (!loadedMessageIds.contains(entry.key)) {
            messages.add(
              ChatMessageMapper.rebindOwnership(
                entry.value,
                currentUserId: currentUserId,
              ),
            );
          }
        }
      }
      messages.sort((left, right) {
        final byTime = left.timestamp.compareTo(right.timestamp);
        return byTime != 0 ? byTime : left.msgId.compareTo(right.msgId);
      });

      await globalUtil.replaceChatRecords(_conversationKey, messages);

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

  Future<void> _normalizeCachedMessageOwnership() async {
    final globalUtil = GlobalUtil();
    final currentUserId = globalUtil.userName ?? '';
    if (currentUserId.isEmpty) return;
    final messages =
        globalUtil
            .getChatRecords(_conversationKey)
            .map(
              (message) => ChatMessageMapper.rebindOwnership(
                message,
                currentUserId: currentUserId,
              ),
            )
            .toList()
          ..sort((left, right) {
            final byTime = left.timestamp.compareTo(right.timestamp);
            return byTime != 0 ? byTime : left.msgId.compareTo(right.msgId);
          });
    if (messages.isNotEmpty) {
      await globalUtil.replaceChatRecords(_conversationKey, messages);
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
        .getChatRecords(_conversationKey)
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

    final incomingMessageIds = globalUtil
        .getChatRecords(_conversationKey)
        .where((message) => !message.isMe && message.msgId > 0)
        .map((message) => message.msgId);
    if (incomingMessageIds.isEmpty) return;
    final readThroughMsgId = incomingMessageIds.reduce(
      (current, next) => next > current ? next : current,
    );
    _wsManager.send({
      'type': 'groupChatRead',
      'reader': currentUserId,
      'groupId': widget.groupId,
      'sessionId': widget.groupId,
      'readThroughMsgId': readThroughMsgId,
    });
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

      final currentMessages = List<Message>.from(
        globalUtil.getChatRecords(_conversationKey),
      );

      // 群聊必须使用群聊记录接口，不能复用单聊记录接口。
      await _loadGroupChatRecords(
        limit: currentMessages.length + 100,
        scrollToBottom: false,
      );

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('加载更多聊天记录失败: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  // 发送图片消息
  Future<void> _sendImageMessage(
    XFile imageFile,
    CancelToken cancelToken,
  ) async {
    try {
      final globalUtil = GlobalUtil();
      if (!_wsManager.isConnected) {
        throw Exception('当前网络未连接，请稍后重试');
      }

      // 获取当前时间和消息ID
      String time = _getTime();
      int msgId = DateTime.now().millisecondsSinceEpoch;
      String conversationId = widget.groupId.toString();

      // 生成图片文件名
      String imageName = '${globalUtil.userName}_${widget.groupId}_$msgId.jpg';
      // 上传图片到服务器
      await _uploadImage(imageFile, imageName, cancelToken);
      // 创建消息对象
      Message newMessage = Message(
        msgId: msgId,
        content: imageName,
        isMe: true,
        time: time,
        isRead: false,
        conversationId: conversationId,
        messageType: MessageType.image,
        status: MessageStatus.sending,
        senderId: globalUtil.userName,
      );

      // 添加消息到全局聊天记录
      globalUtil.addMessage(_conversationKey, newMessage);
      _initializeOutgoingReadStatus(msgId);

      // 更新UI并滚动到底部
      setState(() {});
      _scrollToBottom();

      // 使用WebSocket发送消息
      if (_wsManager.isConnected) {
        // 构建并发送WebSocket消息
        final queued = _sendWebSocketMessage(
          msgId: msgId,
          content: imageName,
          receiver: widget.groupId,
          conversationId: conversationId,
          messageType: MessageType.image,
        );

        if (!queued) newMessage.status = MessageStatus.failed;

        // 更新UI并滚动到底部
        setState(() {});
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('发送图片消息失败: $e');
      rethrow;
    }
  }

  // 上传图片到服务器
  Future<void> _uploadImage(
    XFile imageFile,
    String imageName,
    CancelToken cancelToken,
  ) async {
    try {
      if (await imageFile.length() > 5 * 1024 * 1024) {
        throw Exception('图片压缩后仍超过5MB，请选择较小的图片');
      }
      await HttpUtil().uploadImageFile(
        imageName,
        imageFile.path,
        cancelToken: cancelToken,
      );

      debugPrint('Image uploaded successfully');
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  // 选择图片
  Future<void> _pickImage() async {
    if (_isUploadingImage) return;
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedFile != null) {
        if (mounted) setState(() => _isUploadingImage = true);
        final cancelToken = CancelToken();
        _imageUploadCancelToken = cancelToken;
        await _sendImageMessage(pickedFile, cancelToken);
      }
    } catch (e) {
      debugPrint('选择图片失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('图片发送失败：$e')));
      }
    } finally {
      _imageUploadCancelToken = null;
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickVideo() async {
    if (_isUploadingVideo || _isUploadingImage) return;
    Message? pendingMessage;
    int? pendingMessageId;
    try {
      final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      await validateVideoFile(video.path);
      final global = GlobalUtil();
      final msgId = DateTime.now().millisecondsSinceEpoch;
      pendingMessageId = msgId;
      final videoName =
          '${global.userName}_${widget.groupId}_$msgId.${videoExtension(video.path)}';
      pendingMessage = Message(
        msgId: msgId,
        content: videoName,
        isMe: true,
        time: _getTime(),
        isRead: false,
        conversationId: widget.groupId.toString(),
        messageType: MessageType.video,
        status: MessageStatus.sending,
        senderId: global.userName,
      );
      global.addMessage(_conversationKey, pendingMessage);
      _initializeOutgoingReadStatus(msgId);
      if (mounted) {
        setState(() {
          _isUploadingVideo = true;
          _videoUploadProgress = 0;
          _localVideoPaths[msgId] = video.path;
          _videoMessageProgress[msgId] = 0;
          _failedVideoMessageIds.remove(msgId);
        });
        _scrollToBottom();
      }

      if (!_wsManager.isConnected) throw Exception('当前网络未连接，请稍后重试');
      final cancelToken = CancelToken();
      _videoUploadCancelToken = cancelToken;
      await HttpUtil().uploadVideoFile(
        videoName,
        video.path,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (mounted && total > 0) {
            final progress = (sent / total).clamp(0.0, 1.0);
            setState(() {
              _videoUploadProgress = progress;
              _videoMessageProgress[msgId] = progress;
            });
          }
        },
      );
      if (mounted) setState(() => _videoMessageProgress[msgId] = 1);
      final queued = _sendWebSocketMessage(
        msgId: msgId,
        content: videoName,
        receiver: widget.groupId,
        conversationId: pendingMessage.conversationId,
        messageType: MessageType.video,
      );
      if (!queued) {
        throw Exception('消息发送失败，请检查网络连接');
      }
      _scrollToBottom();
    } catch (error) {
      if (pendingMessage != null) pendingMessage.status = MessageStatus.failed;
      if (mounted) {
        if (pendingMessageId != null) {
          setState(() {
            _videoMessageProgress.remove(pendingMessageId);
            _failedVideoMessageIds.add(pendingMessageId!);
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('视频发送失败：$error')));
      }
    } finally {
      _videoUploadCancelToken = null;
      if (mounted)
        setState(() {
          _isUploadingVideo = false;
          _videoUploadProgress = 0;
        });
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
        case 'groupChatReadCallback':
          _handleGroupReadCallback(parsedMessage);
          break;
        case 'groupChatHistoryDeleted':
          unawaited(_handleGroupHistoryDeleted(parsedMessage));
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

  Future<void> _handleGroupHistoryDeleted(
    Map<String, dynamic> messageData,
  ) async {
    if (_parseInt(messageData['groupId']) != widget.groupId ||
        _isHandlingHistoryDeletion) {
      return;
    }
    _isHandlingHistoryDeletion = true;
    await GlobalUtil().deleteChatRecords(_conversationKey);
    _messageReadStatus.clear();
    _sentReadAckMessageIds.clear();
    if (!mounted) return;

    final navigator = Navigator.of(context);
    var removedGroupChatRoute = false;
    navigator.popUntil((route) {
      if (route.settings.name == '/groupChatDialog') {
        removedGroupChatRoute = true;
        return false;
      }
      if (route.settings.name == '/groupChatSettings') return false;
      // 先关闭可能存在的已读列表、图片预览等匿名弹层，再移除群聊页面。
      return removedGroupChatRoute;
    });
    final notification =
        messageData['message']?.toString() ?? '群主或管理员已删除当前群聊的全部聊天记录';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      showDialog<void>(
        context: navigator.context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('群聊通知'),
          content: Text(notification),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    });
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
    final clientMsgId = _parseInt(messageData['clientMsgId']);
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
    final normalizedTimestamp = timestamp <= 0
        ? DateTime.now().millisecondsSinceEpoch
        : timestamp < 1000000000000
        ? timestamp * 1000
        : timestamp;
    String sendTime = _formatTimestamp(normalizedTimestamp);

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
        _conversationKey,
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
          messageType: switch (msgType) {
            2 => MessageType.image,
            3 => MessageType.audio,
            4 => MessageType.video,
            _ => MessageType.text,
          },
          status: MessageStatus.sent,
          senderId: sender,
          timestamp: normalizedTimestamp,
        );

        debugPrint(
          '创建新消息: msgId=$msgId, isMe=${sender == globalUtil.userName}, sender=$sender',
        );

        // 添加消息到全局聊天记录
        globalUtil.addMessage(_conversationKey, newMessage);

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
          _sendReadAck(msgId, sender, clientMsgId: clientMsgId);
        }
      }
    } else {
      debugPrint('消息数据无效: sender=$sender, content=$content');
    }
  }

  void _handleGroupReadCallback(Map<String, dynamic> messageData) {
    if (_parseInt(messageData['code']) != 100 ||
        _parseInt(messageData['groupId']) != widget.groupId) {
      return;
    }
    final reader = messageData['reader']?.toString() ?? '';
    final readThroughMsgId = _parseInt(messageData['readThroughMsgId']);
    final readTime = _parseInt(messageData['readTime']);
    if (reader.isEmpty || readThroughMsgId <= 0) return;

    final currentUserId = GlobalUtil().userName;
    if (reader == currentUserId) {
      GlobalUtil().clearUnreadMessages(_conversationKey);
    }
    if (reader != currentUserId) {
      for (final message in GlobalUtil().getChatRecords(_conversationKey)) {
        if (message.isMe && message.msgId <= readThroughMsgId) {
          message.isRead = true;
          _updateMessageReadStatus(message.msgId, reader, readTime);
        }
      }
    }
    if (mounted) setState(() {});
  }

  // 处理聊天确认回调
  void _handleChatCallback(Map<String, dynamic> messageData) {
    final globalUtil = GlobalUtil();
    int msgId = _parseInt(messageData['msgId']);
    String sessionId = messageData['sessionId']?.toString() ?? '';
    if (sessionId != widget.groupId.toString()) {
      return;
    }
    final clientMsgId = _parseInt(messageData['clientMsgId']);
    if (clientMsgId > 0) {
      globalUtil.reconcileOutgoingMessageId(clientMsgId, msgId);
      final localVideoPath = _localVideoPaths.remove(clientMsgId);
      if (localVideoPath != null) _localVideoPaths[msgId] = localVideoPath;
      final progress = _videoMessageProgress.remove(clientMsgId);
      if (progress != null) _videoMessageProgress[msgId] = progress;
      if (_failedVideoMessageIds.remove(clientMsgId)) {
        _failedVideoMessageIds.add(msgId);
      }
      final statusIndex = _messageReadStatus.indexWhere(
        (status) => _parseInt(status['msgId']) == clientMsgId,
      );
      if (statusIndex != -1) _messageReadStatus[statusIndex]['msgId'] = msgId;
      globalUtil.updateOutgoingMessageStatus(
        msgId,
        _parseInt(messageData['code']) == 100
            ? MessageStatus.sent
            : MessageStatus.failed,
      );
      if (_parseInt(messageData['code']) == 100) {
        _videoMessageProgress.remove(msgId);
      } else {
        _videoMessageProgress.remove(msgId);
        if (_localVideoPaths.containsKey(msgId)) {
          _failedVideoMessageIds.add(msgId);
        }
      }
    }
    String status = messageData['status']?.toString() ?? '';
    String sender = messageData['sender']?.toString() ?? '';
    int readTime = _parseInt(
      messageData['readTime'],
      fallback: DateTime.now().millisecondsSinceEpoch,
    );
    // 更新消息状态
    List<Message> groupMessages = globalUtil.getChatRecords(_conversationKey);
    for (var message in groupMessages) {
      if (message.msgId == msgId) {
        if (status == 'success' && message.isMe) {
          message.status = MessageStatus.sent;
          _videoMessageProgress.remove(msgId);
        } else if (status == 'failed' && message.isMe) {
          message.status = MessageStatus.failed;
          _videoMessageProgress.remove(msgId);
          if (message.messageType == MessageType.video) {
            _failedVideoMessageIds.add(msgId);
          }
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
  void _sendReadAck(int msgId, String receiveId, {int clientMsgId = 0}) {
    if (_wsManager.isConnected) {
      _wsManager.send({
        'type': 'groupChatCallback',
        'msgId': msgId,
        'receiveId': receiveId,
        'sender': GlobalUtil().userName,
        'groupId': widget.groupId,
        'sessionId': widget.groupId,
        'status': 'read',
        if (clientMsgId > 0) 'clientMsgId': clientMsgId,
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
  void _scrollToBottom({bool completeInitialPositioning = false}) {
    if (completeInitialPositioning) {
      _initialPositioningRequested = true;
    }
    final request = ++_scrollToBottomRequest;
    ChatScrollUtil.scheduleJumpToBottom(
      controller: _scrollController,
      isActive: () => mounted && request == _scrollToBottomRequest,
      reversed: true,
      onComplete: _initialPositioningRequested
          ? () {
              if (mounted && request == _scrollToBottomRequest) {
                _isInitialScrollPending = false;
                _initialPositioningRequested = false;
              }
            }
          : null,
    );
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
    GroupRouteRegistry.leave(widget.groupId);
    _imageUploadCancelToken?.cancel('群聊页面已关闭');
    _videoUploadCancelToken?.cancel('群聊页面已关闭');
    _audioUploadCancelToken?.cancel('群聊页面已关闭');
    // 离开页面前再次提交已读水位，避免会话列表重新出现已读消息红点。
    _sendReadAcksForLoadedMessages();
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
        leading: AppBackButton(
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
            onPressed: () async {
              // 进入群聊设置页面
              final deleted = await Navigator.pushNamed(
                context,
                '/groupChatSettings',
                arguments: {
                  'groupId': widget.groupId.toString(),
                  'groupName': _currentGroupName,
                },
              );
              if (deleted == true && mounted) {
                await _handleGroupHistoryDeleted({
                  'groupId': widget.groupId,
                  'message': '群聊记录已删除',
                });
              }
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // 点击空白区域隐藏键盘
          FocusScope.of(context).unfocus();
        },
        child: ChatBackground(
          child: Column(
            //聊天气泡
            children: [
              Expanded(
                child: TopAlignedReversedList(
                  padding: EdgeInsets.all(8.0),
                  controller: _scrollController,
                  // 使用当前聊天群的全局消息列表，如果不存在则使用空列表
                  itemCount: GlobalUtil()
                      .getChatRecords(_conversationKey)
                      .length,
                  itemBuilder: (context, index) {
                    // 获取当前聊天群的全局消息列表
                    final globalUtil = GlobalUtil();
                    final groupMessages = globalUtil.getChatRecords(
                      _conversationKey,
                    );
                    final message =
                        groupMessages[groupMessages.length - 1 - index];
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
                      localVideoPath: _localVideoPaths[message.msgId],
                      videoUploadProgress: _videoMessageProgress[message.msgId],
                      videoUploadFailed: _failedVideoMessageIds.contains(
                        message.msgId,
                      ),
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
              child: HoldToRecordField(
                controller: _textController,
                focusNode: _textFieldFocusNode,
                enabled: !_isUploadingAudio,
                onChanged: (text) =>
                    setState(() => _isComposing = text.trim().isNotEmpty),
                onSubmitted: _handleSubmitted,
                onRecorded: _handleVoiceRecorded,
                onError: _showVoiceError,
              ),
            ),
            if (_isUploadingAudio)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            IconButton(
              icon: _isUploadingVideo
                  ? SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        value: _videoUploadProgress > 0
                            ? _videoUploadProgress
                            : null,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.video_library_outlined),
              onPressed: _isUploadingVideo ? null : _pickVideo,
            ),
            _isUploadingImage
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: _pickImage,
                  ),
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

  void _showVoiceError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleVoiceRecorded(VoiceRecordingResult recording) async {
    final global = GlobalUtil();
    final sender = global.userName ?? '';
    if (sender.isEmpty || _isUploadingAudio) return;
    final msgId = DateTime.now().millisecondsSinceEpoch;
    final audioName = '${sender}_${widget.groupId}_$msgId.m4a';
    final cancelToken = CancelToken();
    _audioUploadCancelToken = cancelToken;
    setState(() => _isUploadingAudio = true);
    try {
      await HttpUtil().uploadAudioFile(
        audioName,
        recording.path,
        userName: sender,
        cancelToken: cancelToken,
      );
      final payload = VoiceMessagePayload(
        audioName: audioName,
        durationMs: recording.durationMs,
      ).encode();
      final message = Message(
        msgId: msgId,
        content: payload,
        isMe: true,
        time: _getTime(),
        isRead: false,
        conversationId: widget.groupId.toString(),
        messageType: MessageType.audio,
        status: MessageStatus.sending,
        senderId: sender,
      );
      global.addMessage(_conversationKey, message);
      _initializeOutgoingReadStatus(msgId);
      final queued = _sendWebSocketMessage(
        msgId: msgId,
        content: payload,
        receiver: widget.groupId,
        conversationId: message.conversationId,
        messageType: MessageType.audio,
      );
      if (!queued) message.status = MessageStatus.failed;
      if (mounted) {
        setState(() {});
        _scrollToBottom();
      }
    } catch (error) {
      if (error is! DioException || !CancelToken.isCancel(error)) {
        _showVoiceError('语音发送失败，请稍后重试');
      }
    } finally {
      _audioUploadCancelToken = null;
      final file = File(recording.path);
      if (await file.exists()) await file.delete();
      if (mounted) setState(() => _isUploadingAudio = false);
    }
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
      status: MessageStatus.sending,
      senderId: globalUtil.userName,
    );

    // 添加消息到全局聊天记录
    globalUtil.addMessage(_conversationKey, newMessage);

    // 新消息默认由除发送者外的当前群成员组成未读名单。
    _initializeOutgoingReadStatus(msgId);

    // 更新UI并滚动到底部
    setState(() {});
    _scrollToBottom();

    // 使用WebSocket发送消息
    if (_wsManager.isConnected) {
      // 构建并发送WebSocket消息
      final queued = _sendWebSocketMessage(
        msgId: msgId,
        content: text,
        receiver: widget.groupId,
        conversationId: conversationId,
        messageType: MessageType.text,
      );

      if (!queued) newMessage.status = MessageStatus.failed;

      // 更新UI并滚动到底部
      setState(() {});
      _scrollToBottom();
    } else {
      debugPrint('WebSocket未连接,消息发送失败');
      newMessage.status = MessageStatus.failed;
      setState(() {});
    }
  }

  // 发送WebSocket消息的通用方法
  bool _sendWebSocketMessage({
    required int msgId,
    required String content,
    required int receiver,
    required String conversationId,
    required MessageType messageType,
  }) {
    // 根据消息类型设置msgType
    final msgType = switch (messageType) {
      MessageType.image => 2,
      MessageType.audio => 3,
      MessageType.video => 4,
      _ => 1,
    };

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
    final queued = _wsManager.send(messageData);
    debugPrint('消息已发送');
    return queued;
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
                              String? avatarUrl;
                              if (member != null) {
                                try {
                                  avatarUrl = GlobalUtil().getImageURL(
                                    userId,
                                    member.avatar.trim().isEmpty
                                        ? 'head.jpg'
                                        : member.avatar.trim(),
                                  );
                                } catch (error) {
                                  debugPrint('生成已读成员头像地址失败: $error');
                                }
                              }
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey[200],
                                  child: avatarUrl == null
                                      ? Text(initial)
                                      : ClipOval(
                                          child: CachedNetworkImage(
                                            cacheManager: AppImageCache.manager,
                                            imageUrl: avatarUrl,
                                            cacheKey: AppImageCache.cacheKey(
                                              avatarUrl,
                                            ),
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (context, url, error) => Center(
                                                  child: Text(initial),
                                                ),
                                          ),
                                        ),
                                ),
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
  final String? localVideoPath;
  final double? videoUploadProgress;
  final bool videoUploadFailed;
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
    this.localVideoPath,
    this.videoUploadProgress,
    this.videoUploadFailed = false,
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
                          ? AppImageCache.provider(_getSenderAvatar()!)
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
                child: switch (message.messageType) {
                  MessageType.text => _buildTextBubble(context),
                  MessageType.video => AppVideoPreview(
                    source:
                        localVideoPath ??
                        globalUtil.getVideoURL(
                          message.senderId ?? globalUtil.userName ?? '',
                          message.content,
                        ),
                    isLocal: localVideoPath != null,
                    uploadProgress: videoUploadProgress,
                    uploadFailed: videoUploadFailed,
                  ),
                  MessageType.audio => AppVoiceMessage(
                    source: globalUtil.getAudioURL(
                      message.senderId ?? globalUtil.userName ?? '',
                      VoiceMessagePayload.parse(message.content).audioName,
                    ),
                    payload: VoiceMessagePayload.parse(message.content),
                    isMe: message.isMe,
                  ),
                  _ => _buildImageBubble(context),
                },
              ),
              // 自己的头像
              if (message.isMe) ...[
                Container(
                  margin: EdgeInsets.only(left: 8.0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: _getSelfAvatar() != null
                        ? AppImageCache.provider(_getSelfAvatar()!)
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
    final imageUrl = _resolveImageUrl();
    return GestureDetector(
      onTap: () => showFullscreenImage(
        context,
        imageProvider: AppImageCache.provider(imageUrl),
      ),
      onLongPress: () => _showImageActions(context),
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
          cacheManager: AppImageCache.manager,
          imageUrl: imageUrl,
          cacheKey: AppImageCache.cacheKey(imageUrl),
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

  String _resolveImageUrl() {
    return AppMediaUrl.resolveMessageImage(
      content: message.content,
      senderId: message.senderId,
      currentUserId: globalUtil.userName ?? '',
      isMine: message.isMe,
      buildServerUrl: globalUtil.getImageURL,
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
