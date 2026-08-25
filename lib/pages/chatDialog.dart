import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart'; // 暂时禁用，等待修复兼容性问题
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/gloabl.dart';
import '../model/friendInfoModel.dart';
import '../utils/WebSocketManager.dart';
import '../model/messageModel.dart';
import '../utils/http.dart';
import '../utils/user_profile_navigator.dart';
import '../utils/presence_event.dart';
import '../core/cache/app_image_cache.dart';
import '../shared/widgets/app_back_button.dart';
import '../shared/widgets/chat_more_actions_sheet.dart';
import '../shared/widgets/chat_composer_panel.dart';
import '../shared/widgets/chat_composer_toolbar.dart';
import '../shared/widgets/chat_time_separator.dart';
import '../shared/widgets/fullscreen_image_viewer.dart';
import '../shared/utils/chat_scroll_util.dart';
import '../shared/widgets/chat_background.dart';
import '../features/location/data/app_location_service.dart';
import '../features/location/domain/distance_retry.dart';
import '../features/location/presentation/chat_location_draft.dart';
import '../core/media/video_media.dart';
import '../core/media/chat_file.dart';
import '../core/media/app_media_url.dart';
import '../shared/widgets/app_video_player.dart';
import '../shared/widgets/chat_file_message.dart';
import '../shared/widgets/app_voice_message.dart';
import '../shared/widgets/hold_to_record_field.dart';
import '../shared/widgets/message_action_menu.dart';
import '../shared/widgets/quoted_message_view.dart';
import '../core/media/chat_media_saver.dart';
import '../core/media/voice_message.dart';
import '../core/media/voice_media.dart';
import 'videoCallPage.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_theme_context.dart';
import '../features/privacy/application/privacy_settings_service.dart';

class ChatDialogPage extends StatefulWidget {
  ChatDialogPage({Key? key}) : super(key: key);
  @override
  _ChatDialogPageState createState() => _ChatDialogPageState();
}

class _ChatDialogPageState extends State<ChatDialogPage> {
  PrivacySettingsService get _privacy => PrivacySettingsService.instance;

  bool _canSendInCurrentMode() {
    if (!_privacy.enabled || friendInfo?.isOnline == true) return true;
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('隐私模式下无法向离线用户发送消息')));
    }
    return false;
  }

  String? id;
  FriendInfoModel? friendInfo;
  WebSocketManager _wsManager = WebSocketManager();
  WebSocketMessageSubscription? _messageSubscription;
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
  bool _isUploadingFile = false;
  double _fileUploadProgress = 0;
  CancelToken? _fileUploadCancelToken;
  final Map<int, double> _fileMessageProgress = {};
  final Set<int> _failedFileMessageIds = {};
  CancelToken? _audioUploadCancelToken;
  bool _isUploadingAudio = false;
  bool _isResolvingLocation = false;
  bool _isMoreActionsVisible = false;
  MessageQuote? _pendingQuote;
  Timer? _distanceTimer;
  String? _distanceStartedFor;
  int? _distanceMeters;
  bool _distanceLoading = false;
  String? _distanceStatus;
  static const int _distanceMaxAttempts = 2;
  static const Duration _distanceAttemptTimeout = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    GlobalUtil().privacyMessagesRevision.addListener(_refreshPrivacyMessages);
    _textFieldFocusNode.addListener(_handleComposerFocusChanged);

    // 为滚动控制器添加监听器，实现向上滑动加载更多
    _scrollController.addListener(() {
      // 当滚动到顶部时，加载更多聊天记录
      final atTop =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 5.0; // 允许5像素的误差

      debugPrint(
        '滚动位置: ${_scrollController.position.pixels}, 最大滚动位置: ${_scrollController.position.maxScrollExtent}',
      );
      debugPrint('是否滚动到顶部: $atTop');

      if (atTop && !_isInitialScrollPending) {
        debugPrint('触发加载更多聊天记录');
        _loadMoreChatRecords();
      }
    });
  }

  void _refreshPrivacyMessages() {
    if (mounted) setState(() {});
  }

  void _handleComposerFocusChanged() {
    if (_textFieldFocusNode.hasFocus && _isMoreActionsVisible && mounted) {
      setState(() => _isMoreActionsVisible = false);
    }
  }

  // 加载更多聊天记录
  Future<void> _loadMoreChatRecords() async {
    if (id == null || _isLoadingMore) {
      debugPrint('加载更多聊天记录：已跳过（id为null或正在加载中）');
      return;
    }

    try {
      _isLoadingMore = true;
      final globalUtil = GlobalUtil();
      debugPrint('开始加载更多聊天记录...');

      final currentMessages = List<Message>.from(
        globalUtil.getChatRecords(id!),
      );
      debugPrint('当前记录数量: ${currentMessages.length}');

      debugPrint('调用API加载更多记录...');
      await globalUtil.loadMoreChatRecords(id!);
      debugPrint('API调用完成');

      final newMessages = globalUtil.getChatRecords(id!);
      debugPrint('新记录数量: ${newMessages.length}');

      final addedMessageCount = newMessages.length - currentMessages.length;
      debugPrint('新增记录数量: $addedMessageCount');

      if (mounted) setState(() {});

      debugPrint('成功加载更多聊天记录，新增$addedMessageCount条，当前共${newMessages.length}条');
    } catch (e) {
      debugPrint('加载更多聊天记录失败: $e');
      // 打印更详细的错误信息，包括堆栈跟踪
      debugPrint(e.toString());
      if (e is Exception) {
        debugPrint('异常类型: ${e.runtimeType}');
      }
    } finally {
      _isLoadingMore = false;
      debugPrint('加载更多聊天记录完成，_isLoadingMore设置为false');
    }
  }

  // 发送图片消息
  Future<void> _sendImageMessage(
    XFile imageFile,
    CancelToken cancelToken,
  ) async {
    if (!_canSendInCurrentMode()) return;
    try {
      final globalUtil = GlobalUtil();
      String receiver = friendInfo?.userName ?? '';

      if (receiver.isEmpty) {
        debugPrint('ERROR: 无法发送图片消息，接收者userName为空');
        return;
      }
      if (!_wsManager.isConnected) {
        throw Exception('当前网络未连接，请稍后重试');
      }

      // 获取当前时间和消息ID
      String time = _getTime();
      int msgId = DateTime.now().millisecondsSinceEpoch;
      String conversationId = _generateConversationId();

      // 生成图片文件名：当前用户的UserName_发送用户的UserName_时间戳
      String imageName = '${globalUtil.userName}_${receiver}_$msgId.jpg';

      // 上传图片到服务器
      await _uploadImage(imageFile, imageName, cancelToken);

      // 创建图片消息对象，状态为发送中
      Message newMessage = Message(
        msgId: msgId,
        content: imageName, // 图片消息的content存储图片名
        isMe: true,
        time: time,
        isRead: false,
        conversationId: conversationId,
        messageType: MessageType.image,
        status: MessageStatus.sending,
        isPrivacy: _privacy.enabled,
        privacyReadDelaySeconds: _privacy.settings.readDestroySeconds,
        privacyUnreadDelaySeconds: _privacy.settings.unreadDestroySeconds,
      );

      // 添加消息到全局聊天记录
      globalUtil.addMessage(receiver, newMessage);

      // 更新UI并滚动到底部
      setState(() {});
      _scrollToBottom();

      // 使用WebSocket发送图片消息
      if (_wsManager.isConnected) {
        final queued = _sendWebSocketMessage(
          msgId: msgId,
          content: imageName, // 图片消息的content存储图片名
          receiver: receiver,
          conversationId: conversationId,
          messageType: MessageType.image,
        );

        if (!queued) newMessage.status = MessageStatus.failed;

        // 更新UI并滚动到底部
        setState(() {});
        _scrollToBottom();
      } else {
        debugPrint('WebSocket未连接,图片消息发送失败');
        // 更新消息状态为发送失败
        List<Message> friendMessages = globalUtil.getChatRecords(receiver);
        for (var message in friendMessages) {
          if (message.msgId == msgId && message.isMe) {
            message.status = MessageStatus.failed;
            break;
          }
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error sending image message: $e');
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
        queryParameters: _privacy.enabled ? {'privacy': '1'} : null,
        cancelToken: cancelToken,
      );

      debugPrint('Image uploaded successfully');
    } catch (e) {
      debugPrint('Error uploading image: $e');
      rethrow;
    }
  }

  // 选择图片
  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    if (_isUploadingImage) return;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (image != null) {
        if (mounted) setState(() => _isUploadingImage = true);
        final cancelToken = CancelToken();
        _imageUploadCancelToken = cancelToken;
        await _sendImageMessage(image, cancelToken);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
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

  Future<void> _pickVideo({ImageSource source = ImageSource.gallery}) async {
    if (!_canSendInCurrentMode()) return;
    if (_isUploadingVideo || _isUploadingImage) return;
    Message? pendingMessage;
    int? pendingMessageId;
    try {
      final video = await ImagePicker().pickVideo(source: source);
      if (video == null) return;
      await validateVideoFile(video.path);
      final receiver = friendInfo?.userName ?? '';
      if (receiver.isEmpty) throw Exception('无法获取接收者信息');
      final global = GlobalUtil();
      final msgId = DateTime.now().millisecondsSinceEpoch;
      pendingMessageId = msgId;
      final videoName =
          '${global.userName}_${receiver}_${msgId}.${videoExtension(video.path)}';
      pendingMessage = Message(
        msgId: msgId,
        content: videoName,
        isMe: true,
        time: _getTime(),
        isRead: false,
        conversationId: _generateConversationId(),
        messageType: MessageType.video,
        status: MessageStatus.sending,
        senderId: global.userName,
        isPrivacy: _privacy.enabled,
        privacyReadDelaySeconds: _privacy.settings.readDestroySeconds,
        privacyUnreadDelaySeconds: _privacy.settings.unreadDestroySeconds,
      );
      global.addMessage(receiver, pendingMessage);
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
        privacy: _privacy.enabled,
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
      unawaited(
        cacheUploadedVideo(
          video.path,
          global.getVideoURL(global.userName ?? '', videoName),
        ),
      );
      if (mounted) setState(() => _videoMessageProgress[msgId] = 1);
      final queued = _sendWebSocketMessage(
        msgId: msgId,
        content: videoName,
        receiver: receiver,
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

  Future<void> _pickFile() async {
    if (!_canSendInCurrentMode()) return;
    if (_isUploadingFile || _isUploadingVideo || _isUploadingImage) return;
    Message? pendingMessage;
    int? pendingMessageId;
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final selected = result.files.single;
      final path = selected.path;
      if (path == null || path.isEmpty) throw Exception('无法读取所选文件');
      final sizeBytes = await validateChatFile(path);
      final receiver = friendInfo?.userName ?? '';
      if (receiver.isEmpty) throw Exception('无法获取接收者信息');
      final global = GlobalUtil();
      final owner = global.userName ?? '';
      if (owner.isEmpty) throw Exception('无法获取当前用户信息');
      final msgId = DateTime.now().millisecondsSinceEpoch;
      pendingMessageId = msgId;
      final storedName = chatFileStoredName(
        ownerId: owner,
        targetId: receiver,
        messageId: msgId,
        originalName: selected.name,
      );
      final payload = ChatFilePayload(
        storedName: storedName,
        originalName: selected.name,
        sizeBytes: sizeBytes,
        ownerId: owner,
      );
      pendingMessage = Message(
        msgId: msgId,
        content: payload.encode(),
        isMe: true,
        time: _getTime(),
        isRead: false,
        conversationId: _generateConversationId(),
        messageType: MessageType.file,
        status: MessageStatus.sending,
        senderId: owner,
        isPrivacy: _privacy.enabled,
        privacyReadDelaySeconds: _privacy.settings.readDestroySeconds,
        privacyUnreadDelaySeconds: _privacy.settings.unreadDestroySeconds,
      );
      global.addMessage(receiver, pendingMessage);
      if (mounted) {
        setState(() {
          _isUploadingFile = true;
          _fileUploadProgress = 0;
          _fileMessageProgress[msgId] = 0;
          _failedFileMessageIds.remove(msgId);
        });
        _scrollToBottom();
      }
      if (!_wsManager.isConnected) throw Exception('当前网络未连接，请稍后重试');
      final cancelToken = CancelToken();
      _fileUploadCancelToken = cancelToken;
      await HttpUtil().uploadChatFile(
        storedName,
        path,
        userName: owner,
        privacy: _privacy.enabled,
        cancelToken: cancelToken,
        onSendProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          final progress = (sent / total).clamp(0.0, 1.0);
          setState(() {
            _fileUploadProgress = progress;
            _fileMessageProgress[msgId] = progress;
          });
        },
      );
      if (mounted) setState(() => _fileMessageProgress[msgId] = 1);
      final queued = _sendWebSocketMessage(
        msgId: msgId,
        content: payload.encode(),
        receiver: receiver,
        conversationId: pendingMessage.conversationId,
        messageType: MessageType.file,
      );
      if (!queued) throw Exception('消息发送失败，请检查网络连接');
      _scrollToBottom();
    } catch (error) {
      if (pendingMessage != null) pendingMessage.status = MessageStatus.failed;
      if (mounted) {
        if (pendingMessageId != null) {
          setState(() {
            _fileMessageProgress.remove(pendingMessageId);
            _failedFileMessageIds.add(pendingMessageId!);
          });
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('文件发送失败：$error')));
      }
    } finally {
      _fileUploadCancelToken = null;
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
          _fileUploadProgress = 0;
        });
      }
    }
  }

  // 处理WebSocket接收的消息
  void _handleWebSocketMessage(dynamic message) {
    try {
      // 打印完整的消息处理流程
      debugPrint('=== WebSocket消息处理开始 ===');
      debugPrint('原始消息: $message');
      debugPrint('消息类型: ${message.runtimeType}');

      // 安全地解析和处理消息
      if (message is String) {
        debugPrint('消息是字符串类型，尝试解析为JSON');
        try {
          dynamic parsedMessage = json.decode(message);
          debugPrint('解析后的JSON消息: $parsedMessage');
          _processParsedMessage(parsedMessage);
        } catch (e) {
          debugPrint('JSON解析失败: $e，将作为普通字符串处理');
          debugPrint('字符串消息内容: $message');
        }
      } else if (message is Map) {
        debugPrint('消息是Map类型，直接处理');
        _processParsedMessage(message);
      } else if (message is List) {
        debugPrint('消息是List类型，长度: ${message.length}');
        debugPrint('List消息内容: $message');
      } else {
        debugPrint('未知消息类型: ${message.runtimeType}');
        debugPrint('未知类型消息内容: $message');
      }

      debugPrint('=== WebSocket消息处理结束 ===');
    } catch (e) {
      debugPrint('处理WebSocket消息失败: $e');
      debugPrint('异常堆栈: ${e.toString()}');
    }
  }

  // 处理解析后的消息
  void _processParsedMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      // 处理不同类型的消息
      String messageType = message['type'] ?? 'message';
      debugPrint('消息类型: $messageType');

      switch (messageType) {
        case 'presence':
          final event = PresenceEvent.tryParse(message);
          if (event != null && event.userName == id) {
            final globalFriend = GlobalUtil().userInfoModel.friendListData
                ?.where((friend) => friend.userName == event.userName)
                .firstOrNull;
            if (globalFriend != null) globalFriend.isOnline = event.isOnline;
            if (mounted) {
              setState(() {
                friendInfo?.isOnline = event.isOnline;
                if (!event.isOnline) {
                  _distanceMeters = null;
                  _distanceStatus = '未知';
                  _distanceLoading = false;
                }
              });
              if (event.isOnline) unawaited(_refreshDistance());
            }
          }
          break;
        case 'message':
          // 普通消息
          debugPrint('处理普通消息');
          _handleReceivedMessage(message);
          break;
        case 'read_ack':
          // 已读确认
          debugPrint('处理已读确认');
          _handleReadAck(message);
          break;
        case 'delivery_ack':
          // 送达确认
          debugPrint('处理送达确认');
          _handleDeliveryAck(message);
          break;
        case 'privacyMessageRead':
          _handleReadAck(message);
          break;
        case 'privacyMessageDestroy':
          final rawId = message['msgId'];
          final msgId = rawId is num
              ? rawId.toInt()
              : int.tryParse(rawId?.toString() ?? '');
          if (msgId != null) GlobalUtil().destroyPrivacyMessage(msgId);
          if (mounted) setState(() {});
          break;
        case 'videoCallAccept':
          // 视频通话接受
          debugPrint('处理视频通话接受');
          break;
        case 'videoCallReject':
          // 视频通话拒绝
          debugPrint('处理视频通话拒绝');
          _handleVideoCallReject(message);
          break;
        default:
          debugPrint('未知消息类型: $messageType');
      }
    } else {
      debugPrint('消息不是Map<String, dynamic>类型，类型: ${message.runtimeType}');
      debugPrint('消息内容: $message');
    }
  }

  // 处理接收到的普通消息
  void _handleReceivedMessage(Map<String, dynamic> messageData) {
    // 打印接收到的消息数据，用于调试
    debugPrint('Received messageData: $messageData');

    // 解析消息内容
    String content = messageData['msgContent'] ?? '';
    // 修复类型不匹配：sendUserId可能是int或String类型
    dynamic senderValue = messageData['sendUserId'];
    String sender = senderValue != null ? senderValue.toString() : '';

    // 处理时间戳：必须确保是int类型
    dynamic timeValue = messageData['sendTime'];
    int timestamp = timeValue != null
        ? (timeValue is int
              ? timeValue
              : int.tryParse(timeValue.toString()) ??
                    DateTime.now().millisecondsSinceEpoch)
        : DateTime.now().millisecondsSinceEpoch;
    // 转换为UI显示的时间格式
    String time = _formatTimestamp(timestamp);

    // 确保msgId是int类型
    dynamic msgIdValue = messageData['msgId'];
    int msgId = msgIdValue != null
        ? (msgIdValue is int
              ? msgIdValue
              : int.tryParse(msgIdValue.toString()) ??
                    DateTime.now().millisecondsSinceEpoch)
        : DateTime.now().millisecondsSinceEpoch;

    final globalUtil = GlobalUtil();
    debugPrint('Received friendName: ${friendInfo?.userName}');
    debugPrint('Sender: $sender, Sender type: ${sender.runtimeType}');
    debugPrint('Current chat user: ${globalUtil.currentChatUserName}');
    debugPrint('Is chatting: ${globalUtil.isChatting}');

    // 根据msgType判断消息类型：1文本 2图片
    final rawMsgType = messageData['msgType'];
    final msgType = rawMsgType is num
        ? rawMsgType.toInt()
        : int.tryParse(rawMsgType?.toString() ?? '') ?? 1;
    final messageType = switch (msgType) {
      2 => MessageType.image,
      3 => MessageType.audio,
      4 => MessageType.video,
      5 => MessageType.file,
      _ => MessageType.text,
    };

    // 创建新消息对象
    Message newMessage = Message(
      msgId: msgId,
      content: content,
      isMe: false,
      time: time,
      isRead: false,
      conversationId: _generateConversationId(),
      messageType: messageType,
      status: MessageStatus.sent,
      senderId: sender,
      quote: MessageQuote.fromExtendInfo(messageData['extendInfo']),
      isPrivacy: messageData['privacyMode'] == true,
      privacyReadDelaySeconds:
          int.tryParse(
            messageData['privacyReadDelaySeconds']?.toString() ?? '',
          ) ??
          10,
      privacyUnreadDelaySeconds:
          int.tryParse(
            messageData['privacyUnreadDelaySeconds']?.toString() ?? '',
          ) ??
          180,
    );

    // 无论是否在当前聊天界面，都将消息添加到全局聊天记录中
    globalUtil.addMessage(sender, newMessage);

    // 检查是否在当前聊天界面且是当前聊天对象的消息
    bool isCurrentChat =
        globalUtil.isChatting == true &&
        globalUtil.currentChatUserName == sender;
    if (isCurrentChat) {
      debugPrint('在当前聊天界面，立即发送已读确认');
      // 在当前聊天界面，立即发送已读确认
      _sendReadAck(msgId);
      // 更新消息状态为已读
      globalUtil.markMessageAsRead(sender, msgId);
    } else {
      debugPrint('不在当前聊天界面，添加到未读消息列表');
      // 不在当前聊天界面，添加到未读消息列表
      globalUtil.addUnreadMessage(sender, msgId);
    }

    // 更新UI
    setState(() {});

    // 如果是当前聊天界面，滚动到底部显示新消息
    if (isCurrentChat) {
      _scrollToBottom();
    }
  }

  // 处理已读确认
  void _handleReadAck(Map<String, dynamic> messageData) {
    // 修复类型不匹配：msgId可能是int或String类型
    dynamic msgIdValue = messageData['msgId'];
    int? msgId;
    if (msgIdValue is int) {
      msgId = msgIdValue;
    } else if (msgIdValue is String) {
      msgId = int.tryParse(msgIdValue);
    }

    if (msgId != null && id != null) {
      // 使用全局聊天记录管理功能标记消息为已读
      final globalUtil = GlobalUtil();
      List<Message> friendMessages = globalUtil.getChatRecords(id!);
      for (var message in friendMessages) {
        if (message.msgId == msgId && message.isMe) {
          message.isRead = true;
          final failed = messageData['status'] == 'failed';
          message.status = failed ? MessageStatus.failed : MessageStatus.sent;
          _videoMessageProgress.remove(msgId);
          if (failed && message.messageType == MessageType.video) {
            _failedVideoMessageIds.add(msgId);
          }
          break;
        }
      }
      // 更新UI
      setState(() {});
    }
  }

  // 处理送达确认
  void _handleDeliveryAck(Map<String, dynamic> messageData) {
    // 修复类型不匹配：msgId可能是int或String类型
    dynamic msgIdValue = messageData['msgId'];
    int? msgId;
    if (msgIdValue is int) {
      msgId = msgIdValue;
    } else if (msgIdValue is String) {
      msgId = int.tryParse(msgIdValue);
    }

    if (msgId != null && id != null) {
      // 使用全局聊天记录管理功能更新消息状态
      final globalUtil = GlobalUtil();
      List<Message> friendMessages = globalUtil.getChatRecords(id!);
      for (var message in friendMessages) {
        if (message.msgId == msgId && message.isMe) {
          final failed = messageData['status'] == 'failed';
          message.status = failed ? MessageStatus.failed : MessageStatus.sent;
          _videoMessageProgress.remove(msgId);
          if (failed && message.messageType == MessageType.video) {
            _failedVideoMessageIds.add(msgId);
          }
          break;
        }
      }
      // 更新UI
      setState(() {});
    }
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

  // 发送已读确认
  void _sendReadAck(int msgId) {
    final isPrivacy = GlobalUtil()
        .getChatRecords(id ?? '')
        .any((message) => message.msgId == msgId && message.isPrivacy);
    if (_wsManager.isConnected) {
      _wsManager.send({
        'type': 'chatCallback',
        'msgId': msgId,
        'receiveId': friendInfo?.userName,
        'sender': GlobalUtil().userName,
        'sessionId': _generateConversationId(),
        if (isPrivacy) 'privacyMode': true,
      });
    }
  }

  //进入聊天界面后调该函数
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从路由参数中获取userName
    debugPrint("nulll------------chatdiag");
    debugPrint(
      "Route settings arguments: ${ModalRoute.of(context)?.settings.arguments}",
    );
    id = ModalRoute.of(context)?.settings.arguments as String?;
    debugPrint("id value: $id");
    if (id != null) {
      // 更新全局聊天状态
      final globalUtil = GlobalUtil();
      globalUtil.isChatting = true;
      globalUtil.currentChatUserName = id;
      // 获取好友信息
      _fetchFriendInfo();

      // 确保WebSocket已连接
      _ensureWebSocketConnected();

      // 标记未读消息为已读
      _markUnreadMessagesAsRead(id!);

      // 初始加载100条聊天记录
      _loadInitialChatRecords();
    }
  }

  // 初始加载聊天记录
  Future<void> _loadInitialChatRecords() async {
    if (id == null) return;

    try {
      final globalUtil = GlobalUtil();

      // 先立即展示本地缓存，再与服务端最近记录合并，避免在线期间漏收后永久缺失。
      await globalUtil.hydrateChatRecords(id!);
      await globalUtil.loadChatRecords(id!, 100);

      if (mounted) setState(() {});

      // 列表采用懒布局，需要持续对齐到底部，直到消息和图片完成布局。
      _scrollToBottom(completeInitialPositioning: true);
    } catch (e) {
      debugPrint('初始加载聊天记录失败: $e');
      _scrollToBottom(completeInitialPositioning: true);
    }
  }

  // 标记未读消息为已读
  Future<void> _markUnreadMessagesAsRead(String receiverName) async {
    try {
      final globalUtil = GlobalUtil();
      final httpUtil = HttpUtil();

      // 获取该用户的未读消息ID列表
      final List<int> unreadMsgIds = globalUtil.getUnreadMessages(receiverName);
      if (unreadMsgIds.isNotEmpty) {
        // 调用API标记消息为已读
        final bool success = await httpUtil.markMessagesAsRead(
          receiverName,
          unreadMsgIds,
        );

        if (success) {
          // 清除本地未读消息记录
          globalUtil.clearUnreadMessages(receiverName);
          debugPrint('标记${unreadMsgIds.length}条消息为已读成功');
        } else {
          debugPrint('标记消息为已读失败');
        }
      }
    } catch (e) {
      debugPrint('标记未读消息为已读时发生错误: $e');
    }
  }

  // 确保WebSocket已连接
  void _ensureWebSocketConnected() {
    _messageSubscription?.cancel();
    _messageSubscription = _wsManager.addMessageListener(
      _handleWebSocketMessage,
    );

    if (!_wsManager.isConnected) {
      _wsManager.connect(
        GlobalUtil().getChatWebSocketURL(GlobalUtil().userName ?? ''),
      );
    }
  }

  void _fetchFriendInfo() {
    final globalUtil = GlobalUtil();
    //final friendList = globalUtil.userInfoModel.friendListData ?? [];
    debugPrint("chatDia-------:$id");
    final foundFriend = globalUtil.getFriendInfoByUserName(id ?? "");
    setState(() {
      friendInfo = foundFriend;
    });
    _startDistanceRefresh();

    // 处理未读消息：进入聊天界面时标记所有未读消息为已读
    if (id != null) {
      // 获取该用户的所有未读消息ID
      List<int> unreadMsgIds = globalUtil.getUnreadMessages(id!);

      // 发送所有未读消息的已读确认
      for (int msgId in unreadMsgIds) {
        _sendReadAck(msgId);
      }

      // 更新全局消息状态为已读
      globalUtil.markAllMessagesAsRead(id!);

      // 清除该用户的未读消息记录
      globalUtil.clearUnreadMessages(id!);
    }

    // 通知聊天列表页面清除该聊天的未读消息数
    _clearUnreadCount();
  }

  void _startDistanceRefresh() {
    final peer = id;
    if (peer == null || peer.isEmpty || _distanceStartedFor == peer) return;
    _distanceStartedFor = peer;
    _distanceTimer?.cancel();
    unawaited(_refreshDistance());
  }

  void _scheduleNextDistanceRefresh() {
    _distanceTimer?.cancel();
    _distanceTimer = Timer(
      const Duration(minutes: 5),
      () => unawaited(_refreshDistance()),
    );
  }

  Future<void> _refreshDistance() async {
    final peer = id;
    if (peer == null || peer.isEmpty || _distanceLoading) return;
    // Never request GPS or the distance API for an offline peer.
    if (friendInfo?.isOnline != true) {
      if (mounted) {
        setState(() {
          _distanceMeters = null;
          _distanceStatus = '未知';
          _distanceLoading = false;
        });
      }
      if (mounted) _scheduleNextDistanceRefresh();
      return;
    }
    if (mounted) {
      setState(() {
        _distanceLoading = true;
        _distanceStatus = null;
      });
    }
    try {
      final distance = await runDistanceAttempts<int?>(
        maxAttempts: _distanceMaxAttempts,
        attemptTimeout: _distanceAttemptTimeout,
        operation: () {
          if (friendInfo?.isOnline != true) {
            throw StateError('好友已离线');
          }
          return AppLocationService().refreshDistance(
            peer,
            timeout: _distanceAttemptTimeout,
          );
        },
        shouldRetry: (error) {
          final message = error.toString();
          // Permission/settings failures cannot be fixed by an immediate retry.
          return !message.contains('设置中开启') &&
              !message.contains('权限') &&
              !message.contains('定位服务') &&
              !message.contains('好友已离线');
        },
      );
      if (!mounted) return;
      if (friendInfo?.isOnline != true) return;
      setState(() {
        _distanceMeters = distance;
        _distanceStatus = distance == null ? '对方暂无位置' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final message = error.toString();
        _distanceMeters = null;
        _distanceStatus = message.contains('设置中开启') ? '位置已关闭' : '未知';
      });
    } finally {
      if (mounted) setState(() => _distanceLoading = false);
      if (mounted) _scheduleNextDistanceRefresh();
    }
  }

  void _clearUnreadCount() {
    final globalUtil = GlobalUtil();
    // 调用全局回调来清除未读消息数
    if (id != null) {
      // 延迟执行，确保不会在构建过程中触发setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        globalUtil.onUnreadCountChanged?.call(id!, 0);
      });
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

  final TextEditingController _textController = TextEditingController();
  bool _isComposing = false;

  Future<void> _showMediaTypePicker(ImageSource source) async {
    if (_isMoreActionsVisible && mounted) {
      setState(() => _isMoreActionsVisible = false);
    }
    FocusScope.of(context).unfocus();
    final mediaType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.appSurface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(source == ImageSource.gallery ? '选择图片' : '拍摄照片'),
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(source == ImageSource.gallery ? '选择视频' : '拍摄视频'),
              onTap: () => Navigator.pop(sheetContext, 'video'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || mediaType == null) return;
    if (mediaType == 'image') {
      await _pickImage(source: source);
    } else {
      await _pickVideo(source: source);
    }
  }

  void _toggleMoreActions() {
    FocusScope.of(context).unfocus();
    setState(() => _isMoreActionsVisible = !_isMoreActionsVisible);
  }

  Future<void> _fillCurrentLocationDraft() async {
    if (_isResolvingLocation) return;
    setState(() => _isResolvingLocation = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('正在获取当前位置…'),
        duration: Duration(seconds: 15),
      ),
    );
    try {
      final place = await AppLocationService().locate();
      if (!mounted) return;
      final locationText = place.address.trim();
      if (locationText.isEmpty) throw Exception('未能解析当前位置');
      messenger.hideCurrentSnackBar();
      replaceChatDraftWithLocation(_textController, locationText);
      setState(() => _isComposing = true);
      _textFieldFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      messenger.showSnackBar(
        SnackBar(content: Text(message.isEmpty ? '位置获取失败，请稍后重试' : message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  Future<void> _handleMoreAction(ChatMoreActionType action) async {
    if (_isMoreActionsVisible && mounted) {
      setState(() => _isMoreActionsVisible = false);
    }
    switch (action) {
      case ChatMoreActionType.gallery:
        await _showMediaTypePicker(ImageSource.gallery);
      case ChatMoreActionType.capture:
        await _showMediaTypePicker(ImageSource.camera);
      case ChatMoreActionType.location:
        await _fillCurrentLocationDraft();
      case ChatMoreActionType.file:
        await _pickFile();
    }
  }

  void _quoteMessage(Message message) {
    final senderLabel = message.isMe
        ? '我'
        : (friendInfo?.remarks ??
              friendInfo?.nickName ??
              friendInfo?.userName ??
              message.senderId ??
              '对方');
    setState(() {
      _pendingQuote = MessageQuote(
        messageId: message.msgId,
        senderId:
            message.senderId ??
            (message.isMe ? GlobalUtil().userName ?? '' : id ?? ''),
        senderLabel: senderLabel,
        preview: messageQuotePreview(message),
        messageType: message.messageType,
      );
      _isMoreActionsVisible = false;
    });
    _textFieldFocusNode.requestFocus();
  }

  void _deleteLocalMessage(Message message) {
    final conversation = id ?? '';
    if (conversation.isEmpty) return;
    GlobalUtil().deleteMessage(conversation, message.msgId);
    setState(() {
      if (_pendingQuote?.messageId == message.msgId) _pendingQuote = null;
    });
  }

  String get _privateChatStatus {
    if (friendInfo?.isOnline != true) return '';
    if (_distanceLoading) return '在线 · 距离计算中';
    if (_distanceMeters != null) {
      return '在线 · 距你 ${formatDistance(_distanceMeters!)}';
    }
    final status = _distanceStatus?.trim() ?? '';
    return status.isEmpty ? '在线' : '在线 · $status';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        centerTitle: true,
        titleSpacing: 0,
        leadingWidth: 56,
        leading: AppBackButton(
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: friendInfo?.isOnline == true && !_distanceLoading
              ? _refreshDistance
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                friendInfo?.remarks ??
                    friendInfo?.nickName ??
                    friendInfo?.userName ??
                    '未知用户',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
              if (_privateChatStatus.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  key: const Key('private_chat_online_status'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _privateChatStatus,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        backgroundColor: context.appSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.appDivider),
        ),
        actions: [
          IconButton(
            key: const ValueKey('private_video_call_button'),
            tooltip: '视频通话',
            icon: Icon(
              Icons.videocam_outlined,
              color: context.appTextPrimary,
              size: 25,
            ),
            onPressed: () {
              // 发起视频通话
              if (id != null) {
                // 在实际应用中，token应该从服务器获取
                // 这里使用临时token（在Agora测试环境中可以使用临时token）
                const token = ''; // 可以使用Agora控制台生成的临时token

                // 发送视频通话邀请
                if (_wsManager.isConnected) {
                  _wsManager.send({
                    'type': 'videoCallInvite',
                    'receiver': id,
                    'sender': GlobalUtil().userName,
                    'channelName': id,
                    'token': token,
                    'time': DateTime.now().millisecondsSinceEpoch,
                  });
                }

                // 使用id作为频道名称
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        VideoCallPage(channelName: id!, token: token),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // 点击空白区域隐藏键盘
          FocusScope.of(context).unfocus();
          if (_isMoreActionsVisible) {
            setState(() => _isMoreActionsVisible = false);
          }
        },
        child: ChatBackground(
          child: Column(
            //聊天气泡
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
                  reverse: true,
                  controller: _scrollController,
                  // 使用当前聊天好友的全局消息列表，如果不存在则使用空列表
                  itemCount: GlobalUtil().getChatRecords(id ?? '').length,
                  itemBuilder: (context, index) {
                    // 获取当前聊天好友的全局消息列表
                    final globalUtil = GlobalUtil();
                    final friendMessages = globalUtil.getChatRecords(id ?? '');
                    final sourceIndex = friendMessages.length - 1 - index;
                    final message = friendMessages[sourceIndex];
                    final previous = sourceIndex > 0
                        ? friendMessages[sourceIndex - 1]
                        : null;
                    return Column(
                      children: [
                        if (shouldShowChatTimeSeparator(
                          current: message,
                          previous: previous,
                        ))
                          ChatTimeSeparator(label: message.time),
                        MessageBubble(
                          message: message,
                          friendInfo: friendInfo,
                          currentUserAvatar: globalUtil.userInfoModel.avatar,
                          onProfileUpdated: () {
                            if (mounted) _fetchFriendInfo();
                          },
                          localVideoPath: _localVideoPaths[message.msgId],
                          videoUploadProgress:
                              _videoMessageProgress[message.msgId],
                          videoUploadFailed: _failedVideoMessageIds.contains(
                            message.msgId,
                          ),
                          fileUploadProgress:
                              _fileMessageProgress[message.msgId],
                          fileUploadFailed: _failedFileMessageIds.contains(
                            message.msgId,
                          ),
                          onDelete: () => _deleteLocalMessage(message),
                          onQuote: () => _quoteMessage(message),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Divider(height: 1, color: context.appDivider),
              ChatComposerPanel(
                composer: _buildTextComposer(),
                moreActionsVisible: _isMoreActionsVisible,
                moreActions: ChatMoreActionsSheet(
                  onSelected: (action) {
                    unawaited(_handleMoreAction(action));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 7, 6, 7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingQuote != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: QuoteComposerPreview(
                quote: _pendingQuote!,
                onClose: () => setState(() => _pendingQuote = null),
              ),
            ),
          ChatComposerToolbar(
            editor: HoldToRecordField(
              controller: _textController,
              focusNode: _textFieldFocusNode,
              enabled: !_isUploadingAudio,
              onChanged: (text) =>
                  setState(() => _isComposing = text.trim().isNotEmpty),
              onSubmitted: _handleSubmitted,
              onRecorded: _handleVoiceRecorded,
              onError: _showVoiceError,
            ),
            isComposing: _isComposing,
            isUploadingAudio: _isUploadingAudio,
            isUploadingMedia:
                _isUploadingVideo || _isUploadingImage || _isUploadingFile,
            mediaProgress: _isUploadingVideo && _videoUploadProgress > 0
                ? _videoUploadProgress
                : _isUploadingFile && _fileUploadProgress > 0
                ? _fileUploadProgress
                : null,
            onMedia: () => _showMediaTypePicker(ImageSource.gallery),
            onMore: _toggleMoreActions,
            onSend: () => _handleSubmitted(_textController.text),
          ),
        ],
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
    if (!_canSendInCurrentMode()) return;
    final receiver = friendInfo?.userName ?? id ?? '';
    final sender = GlobalUtil().userName ?? '';
    if (receiver.isEmpty || sender.isEmpty || _isUploadingAudio) return;
    final msgId = DateTime.now().millisecondsSinceEpoch;
    final audioName = '${sender}_${receiver}_$msgId.m4a';
    final cancelToken = CancelToken();
    _audioUploadCancelToken = cancelToken;
    setState(() => _isUploadingAudio = true);
    try {
      await HttpUtil().uploadAudioFile(
        audioName,
        recording.path,
        userName: sender,
        privacy: _privacy.enabled,
        cancelToken: cancelToken,
      );
      final payload = VoiceMessagePayload(
        audioName: audioName,
        durationMs: recording.durationMs,
        ownerId: sender,
      ).encode();
      if (!_privacy.enabled) {
        await cacheUploadedVoice(
          recording.path,
          GlobalUtil().getAudioURL(sender, audioName),
        );
      }
      final conversationId = _generateConversationId();
      final message = Message(
        msgId: msgId,
        content: payload,
        isMe: true,
        time: _getTime(),
        isRead: false,
        conversationId: conversationId,
        messageType: MessageType.audio,
        status: MessageStatus.sending,
        senderId: sender,
        isPrivacy: _privacy.enabled,
        privacyReadDelaySeconds: _privacy.settings.readDestroySeconds,
        privacyUnreadDelaySeconds: _privacy.settings.unreadDestroySeconds,
      );
      GlobalUtil().addMessage(receiver, message);
      final queued = _sendWebSocketMessage(
        msgId: msgId,
        content: payload,
        receiver: receiver,
        conversationId: conversationId,
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
    if (text.trim().isEmpty || !_canSendInCurrentMode()) return;
    final quote = _pendingQuote;
    _textController.clear();

    // 获取当前时间和消息ID
    String time = _getTime();
    int msgId = DateTime.now().millisecondsSinceEpoch;
    String conversationId = _generateConversationId();
    String receiver = friendInfo?.userName ?? '';

    if (receiver.isEmpty) {
      debugPrint('ERROR: 无法发送消息，接收者userName为空');
      return;
    }

    final globalUtil = GlobalUtil();

    setState(() {
      _isComposing = false;
      _pendingQuote = null;
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
      quote: quote,
      isPrivacy: _privacy.enabled,
      privacyReadDelaySeconds: _privacy.settings.readDestroySeconds,
      privacyUnreadDelaySeconds: _privacy.settings.unreadDestroySeconds,
    );

    // 添加消息到全局聊天记录
    globalUtil.addMessage(receiver, newMessage);

    // 更新UI并滚动到底部
    setState(() {});
    _scrollToBottom();

    // 使用WebSocket发送消息
    if (_wsManager.isConnected) {
      // 构建并发送WebSocket消息
      final queued = _sendWebSocketMessage(
        msgId: msgId,
        content: text,
        receiver: receiver,
        conversationId: conversationId,
        messageType: MessageType.text,
        extendInfo: quote?.encodeExtendInfo(),
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
    required String receiver,
    required String conversationId,
    required MessageType messageType,
    String? extendInfo,
  }) {
    if (_privacy.enabled && friendInfo?.isOnline != true) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('隐私模式下无法向离线用户发送消息')));
      }
      return false;
    }
    // 根据消息类型设置msgType
    final msgType = switch (messageType) {
      MessageType.image => 2,
      MessageType.audio => 3,
      MessageType.video => 4,
      MessageType.file => 5,
      _ => 1,
    };

    // 构建消息数据
    Map<String, dynamic> messageData = {
      'type': 'chat',
      'msgType': msgType, // 1文本 2图片
      'msgId': msgId,
      'msgContent': content,
      'sendUserId': GlobalUtil().userName,
      'receiveId': receiver,
      'sendTime': GlobalUtil.getCurrentTimestamp(),
      'readTime': 0,
      'sessionId': conversationId,
      "receiveType": 1,
      'extendInfo': extendInfo ?? '{}',
      'msgStatus': 1, //1 发送成功  3 已读
      if (_privacy.enabled) ...{
        'privacyMode': true,
        'privacyReadDelaySeconds': _privacy.settings.readDestroySeconds,
        'privacyUnreadDelaySeconds': _privacy.settings.unreadDestroySeconds,
      },
    };

    // 发送WebSocket消息
    return _wsManager.send(messageData);
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

  // 生成会话ID，规则：较大的手机号放在前面，用下划线分隔
  String _generateConversationId() {
    final globalUtil = GlobalUtil();
    String myUserName = globalUtil.userName ?? '';
    String otherUserName = friendInfo?.userName ?? '';
    return GlobalUtil.generateSessionId(myUserName, otherUserName);
  }

  @override
  void dispose() {
    GlobalUtil().privacyMessagesRevision.removeListener(
      _refreshPrivacyMessages,
    );
    _imageUploadCancelToken?.cancel('聊天页面已关闭');
    _videoUploadCancelToken?.cancel('聊天页面已关闭');
    _audioUploadCancelToken?.cancel('聊天页面已关闭');
    _fileUploadCancelToken?.cancel('聊天页面已关闭');
    _distanceTimer?.cancel();
    _messageSubscription?.cancel();
    _textFieldFocusNode.removeListener(_handleComposerFocusChanged);
    _textController.dispose();
    _textFieldFocusNode.dispose();
    _scrollController.dispose();

    // 离开聊天页面时，更新全局聊天状态
    final globalUtil = GlobalUtil();
    globalUtil.isChatting = false;
    globalUtil.currentChatUserName = null;

    super.dispose();
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final FriendInfoModel? friendInfo;
  final String? currentUserAvatar;
  final VoidCallback? onProfileUpdated;
  final String? localVideoPath;
  final double? videoUploadProgress;
  final bool videoUploadFailed;
  final double? fileUploadProgress;
  final bool fileUploadFailed;
  final VoidCallback onDelete;
  final VoidCallback onQuote;
  final globalUtil = GlobalUtil();
  final dio = Dio();
  // 头像 URL 缓存，用于避免重复加载
  static Map<String, String> _avatarCache = {};
  MessageBubble({
    required this.message,
    required this.friendInfo,
    required this.currentUserAvatar,
    this.onProfileUpdated,
    this.localVideoPath,
    this.videoUploadProgress,
    this.videoUploadFailed = false,
    this.fileUploadProgress,
    this.fileUploadFailed = false,
    required this.onDelete,
    required this.onQuote,
  });

  Future<void> _showMessageActions(
    BuildContext context,
    Offset anchor, {
    Rect? targetRect,
  }) async {
    final actions = <MessageActionItem>[
      if (message.messageType == MessageType.text)
        const MessageActionItem(
          type: MessageActionType.copy,
          label: '复制',
          icon: Icons.copy_rounded,
        ),
      if (message.messageType == MessageType.image ||
          message.messageType == MessageType.video)
        const MessageActionItem(
          type: MessageActionType.save,
          label: '保存到本地',
          icon: Icons.download_rounded,
        ),
      const MessageActionItem(
        type: MessageActionType.delete,
        label: '删除',
        icon: Icons.delete_outline_rounded,
      ),
      const MessageActionItem(
        type: MessageActionType.quote,
        label: '引用',
        icon: Icons.format_quote_rounded,
      ),
    ];
    final action = await showMessageActionMenu(
      context: context,
      anchor: anchor,
      targetRect: targetRect,
      actions: actions,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case MessageActionType.copy:
        await Clipboard.setData(ClipboardData(text: message.content));
      case MessageActionType.save:
        await _saveMedia(context);
      case MessageActionType.delete:
        onDelete();
      case MessageActionType.quote:
        onQuote();
      case MessageActionType.speaker:
      case MessageActionType.transcription:
        break;
    }
  }

  Future<void> _saveMedia(BuildContext context) async {
    try {
      const saver = ChatMediaSaver();
      if (message.messageType == MessageType.image) {
        await saver.saveImage(
          source: _resolveImageUrl(),
          fileName: message.content,
        );
      } else if (message.messageType == MessageType.video) {
        await saver.saveVideo(
          source: _resolveVideoUrl(),
          fileName: message.content,
          localPath: localVideoPath,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已保存到系统相册')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请检查相册权限')));
      }
    }
  }

  // 旧版图片菜单，保留用于兼容历史页面结构。
  // ignore: unused_element
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
    String receiver = message.isMe
        ? friendInfo?.userName ?? ""
        : globalUtil.userName ?? "";
    globalUtil.deleteMessage(receiver, message.msgId);
  }

  // 显示文本上下文菜单
  // ignore: unused_element
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
      String receiver = message.isMe
          ? friendInfo?.userName ?? ""
          : globalUtil.userName ?? "";
      globalUtil.deleteMessage(receiver, message.msgId);
    }
  }

  // 显示SnackBar提示的辅助方法
  void _showSnackBar(BuildContext context, bool isSuccess) {
    if (kDebugMode) {
      debugPrint('执行_showSnackBar方法');
      debugPrint('SnackBar Context mounted状态: ${context.mounted}');
    }
    if (context.mounted) {
      try {
        final snackBar = SnackBar(
          content: Text(isSuccess ? '图片保存成功' : '图片保存失败'),
          duration: Duration(seconds: 2),
          action: SnackBarAction(
            label: '关闭',
            onPressed: () {
              if (kDebugMode) {
                debugPrint('SnackBar关闭按钮点击');
              }
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        );
        if (kDebugMode) {
          debugPrint('创建SnackBar成功');
        }
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        if (kDebugMode) {
          debugPrint('SnackBar显示成功');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('显示SnackBar失败: $e');
        }
      }
    }
  }

  // 保存图片到相册
  Future<void> _saveImageToGallery(BuildContext context) async {
    try {
      // 获取图片URL
      String imageURL;
      if (message.isMe) {
        imageURL = globalUtil.getImageURL(
          globalUtil.userName ?? "",
          message.content,
        );
      } else {
        imageURL = globalUtil.getImageURL(
          friendInfo?.userName ?? "",
          message.content,
        );
      }

      // 下载图片
      final response = await dio.get(
        imageURL,
        options: Options(responseType: ResponseType.bytes),
      );
      final Uint8List imageBytes = response.data;

      if (kDebugMode) {
        debugPrint('已下载图片大小: ${imageBytes.lengthInBytes} bytes');
      }

      // 暂时禁用图片保存功能
      // final result = await ImageGallerySaver.saveImage(
      //   Uint8List.fromList(imageBytes),
      //   quality: 100,
      //   name: message.content,
      // );

      // 调试输出结果
      if (kDebugMode) {
        debugPrint('=== 图片保存调试信息 ===');
        debugPrint('图片保存功能已暂时禁用');
      }

      // 暂时总是返回保存成功
      bool saveSuccess = true;
      try {
        // 暂时禁用保存结果判断
        // if (result is Map) {
        //   // 处理Map类型结果
        //   if (result.containsKey('isSuccess')) {
        //     saveSuccess =
        //         result['isSuccess'] == true || result['isSuccess'] == 'true';
        //   } else if (result.containsKey('success')) {
        //     saveSuccess =
        //         result['success'] == true || result['success'] == 'true';
        //   } else if (result.containsKey('result')) {
        //     saveSuccess = result['result'] != null && result['result'] != false;
        //   } else if (result.containsKey('status')) {
        //     saveSuccess =
        //         result['status'] == 1 ||
        //         result['status'] == '1' ||
        //         result['status'] == 'success';
        //   }
        // } else if (result != null) {
        //   // 处理非Map类型结果
        //   saveSuccess = true;
        // }
        if (kDebugMode) {
          debugPrint('保存成功判断结果: $saveSuccess');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('判断保存结果时出错: $e');
        }
        // 出错时默认认为保存成功，因为用户反馈实际已保存
        saveSuccess = true;
      }

      // 显示保存结果 - 确保在任何情况下都能显示
      if (kDebugMode) {
        debugPrint('准备显示保存结果提示');
        debugPrint('Context mounted状态: ${context.mounted}');
        debugPrint('要显示的提示类型: ${saveSuccess ? '成功' : '失败'}');
      }

      // 确保在UI线程执行
      if (context.mounted) {
        // 尝试多种方式显示提示
        try {
          // 方式1: 直接显示AlertDialog
          if (kDebugMode) {
            debugPrint('尝试方式1: 直接显示AlertDialog');
          }
          showDialog(
                context: context,
                barrierDismissible: true,
                builder: (BuildContext dialogContext) {
                  if (kDebugMode) {
                    debugPrint('AlertDialog builder执行');
                  }
                  return AlertDialog(
                    title: Text(saveSuccess ? '保存成功' : '保存失败'),
                    content: Text(saveSuccess ? '图片已成功保存到相册' : '图片保存到相册失败'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          if (kDebugMode) {
                            debugPrint('AlertDialog确定按钮点击');
                          }
                          Navigator.of(dialogContext).pop();
                        },
                        child: Text('确定'),
                      ),
                    ],
                  );
                },
              )
              .then((_) {
                if (kDebugMode) {
                  debugPrint('AlertDialog显示完成');
                }
              })
              .catchError((error) {
                if (kDebugMode) {
                  debugPrint('AlertDialog显示失败: $error');
                }
                // 方式2: 如果AlertDialog失败，使用ScaffoldMessenger
                if (context.mounted) {
                  _showSnackBar(context, saveSuccess);
                }
              });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('方式1执行出错: $e');
          }
          // 方式2: 如果AlertDialog失败，使用ScaffoldMessenger
          if (context.mounted) {
            _showSnackBar(context, saveSuccess);
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('Context已销毁，无法显示任何提示');
        }
      }
    } catch (e) {
      // 仅在开发环境下打印错误
      if (kDebugMode) {
        debugPrint('保存图片失败: $e');
      }
      // 使用BuildContext前检查它是否仍然可用
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('保存失败'),
            content: Text('图片保存到相册失败'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }

  // 构建对方头像
  Widget _buildOtherAvatar(BuildContext context) {
    String userName = friendInfo?.userName ?? "";
    String avatarName = friendInfo?.avatar ?? "head.jpg";
    String newAvatarUrl = globalUtil.getImageURL(userName, avatarName);

    // 检查缓存中是否已有该用户的头像，并且 URL 是否相同
    String avatarUrl;
    if (_avatarCache.containsKey(userName)) {
      String cachedUrl = _avatarCache[userName]!;
      if (cachedUrl == newAvatarUrl) {
        // URL 相同，使用缓存的头像 URL
        avatarUrl = cachedUrl;
      } else {
        // URL 不同，使用新的头像 URL 并更新缓存
        avatarUrl = newAvatarUrl;
        _avatarCache[userName] = newAvatarUrl;
      }
    } else {
      // 缓存中没有，使用新的头像 URL 并加入缓存
      avatarUrl = newAvatarUrl;
      _avatarCache[userName] = newAvatarUrl;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: userName.isEmpty
          ? null
          : () => openUserProfile(
              context,
              userName: userName,
              fallbackNickname: friendInfo?.nickName,
              fallbackAvatarName: avatarName,
              onProfileUpdated: onProfileUpdated,
            ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: CircleAvatar(
          backgroundImage: AppImageCache.provider(avatarUrl),
          backgroundColor: Colors.grey[200],
          radius: 20,
        ),
      ),
    );
  }

  // 构建自己的头像
  Widget _buildSelfAvatar() {
    String userName = globalUtil.userInfoModel.userName ?? "";
    String avatarName = currentUserAvatar ?? "head.jpg";
    String newAvatarUrl = globalUtil.getImageURL(userName, avatarName);

    // 检查缓存中是否已有该用户的头像，并且 URL 是否相同
    String avatarUrl;
    if (_avatarCache.containsKey(userName)) {
      String cachedUrl = _avatarCache[userName]!;
      if (cachedUrl == newAvatarUrl) {
        // URL 相同，使用缓存的头像 URL
        avatarUrl = cachedUrl;
      } else {
        // URL 不同，使用新的头像 URL 并更新缓存
        avatarUrl = newAvatarUrl;
        _avatarCache[userName] = newAvatarUrl;
      }
    } else {
      // 缓存中没有，使用新的头像 URL 并加入缓存
      avatarUrl = newAvatarUrl;
      _avatarCache[userName] = newAvatarUrl;
    }

    return CircleAvatar(
      backgroundImage: AppImageCache.provider(avatarUrl),
      backgroundColor: Colors.grey[200],
      radius: 20,
    );
  }

  // 构建图片消息
  String _resolveImageUrl() {
    late final String url;
    if (message.isMe) {
      url = globalUtil.getImageURL(globalUtil.userName ?? "", message.content);
    } else {
      url = globalUtil.getImageURL(friendInfo?.userName ?? "", message.content);
    }
    return privacyAwareMediaUrl(url, privacy: message.isPrivacy);
  }

  String _resolveVideoUrl() {
    final fallbackOwner = message.isMe
        ? (globalUtil.userName ?? '')
        : (message.senderId ?? friendInfo?.userName ?? '');
    final owner = videoOwnerFromName(
      message.content,
      fallbackOwner: fallbackOwner,
    );
    return privacyAwareMediaUrl(
      globalUtil.getVideoURL(owner, message.content),
      privacy: message.isPrivacy,
    );
  }

  String _resolveAudioUrl() {
    final payload = VoiceMessagePayload.parse(message.content);
    final owner =
        payload.ownerId ??
        (message.isMe
            ? (globalUtil.userName ?? '')
            : (message.senderId ?? friendInfo?.userName ?? ''));
    return privacyAwareMediaUrl(
      globalUtil.getAudioURL(owner, payload.audioName),
      privacy: message.isPrivacy,
    );
  }

  Widget _buildImageMessage() {
    final imageURL = _resolveImageUrl();

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 200.0, // 图片最大宽度
        maxHeight: 200.0, // 图片最大高度
      ),
      // 添加一个固定大小的占位容器，确保布局不会因为图片加载而变化
      child: Container(
        width: 200.0,
        height: 200.0,
        alignment: Alignment.center,
        child: message.isPrivacy
            ? Image.network(
                imageURL,
                fit: BoxFit.cover,
                width: 200,
                height: 200,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined, size: 40),
              )
            : CachedNetworkImage(
                cacheManager: AppImageCache.manager,
                imageUrl: imageURL,
                cacheKey: AppImageCache.cacheKey(imageURL),
                fit: BoxFit.cover,
                width: 200.0,
                height: 200.0,
                progressIndicatorBuilder:
                    (
                      BuildContext context,
                      String url,
                      DownloadProgress? progress,
                    ) {
                      if (progress == null) {
                        return SizedBox(width: 200.0, height: 200.0);
                      } else {
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.totalSize != null
                                ? progress.downloaded /
                                      (progress.totalSize ?? 1)
                                : null,
                          ),
                        );
                      }
                    },
                errorWidget: (BuildContext context, String url, dynamic error) {
                  return Container(
                    width: 200.0,
                    height: 200.0,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 40,
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalBubbleColor = message.isMe
        ? AppColors.primary
        : context.appSurface;
    final bubbleColor = message.isPrivacy
        ? Color.alphaBlend(
            Colors.black.withValues(alpha: message.isMe ? .28 : .14),
            normalBubbleColor,
          )
        : normalBubbleColor;
    final textColor = message.isMe ? Colors.white : context.appTextPrimary;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(message.isMe ? 16 : 5),
      bottomRight: Radius.circular(message.isMe ? 5 : 16),
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: message.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          // 对方消息：头像在左
          if (!message.isMe) _buildOtherAvatar(context),

          // 对方消息：头像和消息之间的间距
          if (!message.isMe) SizedBox(width: 8),

          // 消息内容区域
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // 消息气泡
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPressStart: message.messageType == MessageType.audio
                      ? null
                      : (details) => _showMessageActions(
                          context,
                          details.globalPosition,
                          targetRect: messageActionTargetRect(context),
                        ),
                  child: message.messageType == MessageType.video
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: AppVideoPreview(
                            source: localVideoPath ?? _resolveVideoUrl(),
                            isLocal: localVideoPath != null,
                            uploadProgress: videoUploadProgress,
                            uploadFailed: videoUploadFailed,
                          ),
                        )
                      : message.messageType == MessageType.audio
                      ? AppVoiceMessage(
                          source: _resolveAudioUrl(),
                          payload: VoiceMessagePayload.parse(message.content),
                          isMe: message.isMe,
                          cacheEnabled: !message.isPrivacy,
                          onDelete: onDelete,
                          onQuote: onQuote,
                        )
                      : message.messageType == MessageType.file
                      ? ChatFileMessage(
                          payload: ChatFilePayload.parse(message.content),
                          uploadProgress: fileUploadProgress,
                          uploadFailed: fileUploadFailed,
                        )
                      : message.messageType == MessageType.image
                      ? // 图片消息：使用不同的样式，没有背景色
                        GestureDetector(
                          onTap: () => showFullscreenImage(
                            context,
                            imageProvider: message.isPrivacy
                                ? NetworkImage(_resolveImageUrl())
                                : AppImageCache.provider(_resolveImageUrl()),
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: borderRadius,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildImageMessage(),
                          ),
                        )
                      : message.quote != null
                      ? QuotedTextMessageBubble(
                          quote: message.quote!,
                          text: message.content,
                          bubbleColor: bubbleColor,
                          textColor: textColor,
                          borderRadius: borderRadius,
                        )
                      : Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.68,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: borderRadius,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x10000000),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message.content,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                ),

                if (message.isPrivacy) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_moon_outlined,
                        size: 12,
                        color: context.appTextSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '隐私消息 · 阅后销毁',
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],

                if (message.isMe) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (message.status == MessageStatus.failed)
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 12,
                          color: AppColors.danger,
                        ),
                      if (message.status == MessageStatus.failed)
                        const SizedBox(width: 2),
                      Text(
                        message.status == MessageStatus.failed
                            ? '发送失败'
                            : (message.isRead ? '已读' : '未读'),
                        style: TextStyle(
                          color: message.status == MessageStatus.failed
                              ? AppColors.danger
                              : context.appTextSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 自己消息：消息和头像之间的间距
          if (message.isMe) SizedBox(width: 8),

          // 自己消息：头像在右
          if (message.isMe) _buildSelfAvatar(),
        ],
      ),
    );
  }
}
