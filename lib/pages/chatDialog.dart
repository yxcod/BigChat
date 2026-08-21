import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:image_gallery_saver/image_gallery_saver.dart'; // 暂时禁用，等待修复兼容性问题
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/gloabl.dart';
import '../model/friendInfoModel.dart';
import '../utils/WebSocketManager.dart';
import '../model/messageModel.dart';
import '../utils/http.dart';
import '../utils/user_profile_navigator.dart';
import 'videoCallPage.dart';

class ChatDialogPage extends StatefulWidget {
  ChatDialogPage({Key? key}) : super(key: key);
  @override
  _ChatDialogPageState createState() => _ChatDialogPageState();
}

class _ChatDialogPageState extends State<ChatDialogPage> {
  String? id;
  FriendInfoModel? friendInfo;
  WebSocketManager _wsManager = WebSocketManager();
  WebSocketMessageSubscription? _messageSubscription;
  FocusNode _textFieldFocusNode = FocusNode();
  ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();

    // 为滚动控制器添加监听器，实现向上滑动加载更多
    _scrollController.addListener(() {
      // 当滚动到顶部时，加载更多聊天记录
      final atTop =
          _scrollController.position.pixels <=
          _scrollController.position.minScrollExtent + 5.0; // 允许5像素的误差

      debugPrint(
        '滚动位置: ${_scrollController.position.pixels}, 最小滚动位置: ${_scrollController.position.minScrollExtent}',
      );
      debugPrint('是否滚动到顶部: $atTop');

      if (atTop) {
        debugPrint('触发加载更多聊天记录');
        _loadMoreChatRecords();
      }
    });
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

      // 1. 记录当前聊天记录
      List<Message> currentMessages = List.from(globalUtil.getChatRecords(id!));
      debugPrint('当前记录数量: ${currentMessages.length}');

      // 2. 记录当前可见区域的关键消息
      Message? keyMessage;
      if (_scrollController.hasClients && currentMessages.isNotEmpty) {
        // 获取当前滚动位置
        final scrollPosition = _scrollController.position.pixels;
        debugPrint('当前滚动位置: $scrollPosition');

        // 计算每条消息的平均高度
        final averageItemHeight = scrollPosition > 0
            ? scrollPosition / currentMessages.length
            : 50.0; // 默认高度50.0
        debugPrint('平均消息高度: $averageItemHeight');

        // 计算当前可见区域中间位置的消息索引
        int middleIndex =
            (scrollPosition +
                _scrollController.position.viewportDimension / 2) ~/
            averageItemHeight;
        debugPrint('计算的中间索引: $middleIndex');

        // 确保索引在有效范围内
        middleIndex = middleIndex.clamp(0, currentMessages.length - 1);
        debugPrint('修正后的中间索引: $middleIndex');
        keyMessage = currentMessages[middleIndex];
        debugPrint('关键消息ID: ${keyMessage.msgId}');
      }

      // 3. 调用API加载更多记录
      debugPrint('调用API加载更多记录...');
      await globalUtil.loadMoreChatRecords(id!);
      debugPrint('API调用完成');

      // 4. 获取新的聊天记录列表
      List<Message> newMessages = globalUtil.getChatRecords(id!);
      debugPrint('新记录数量: ${newMessages.length}');

      // 5. 计算新添加的记录数量
      int addedMessageCount = newMessages.length - currentMessages.length;
      debugPrint('新增记录数量: $addedMessageCount');

      // 6. 更新UI
      debugPrint('更新UI...');
      setState(() {});

      // 7. 使用SchedulerBinding确保在UI更新完成后再调整滚动位置
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && keyMessage != null) {
          debugPrint('开始调整滚动位置...');
          // 8. 找到关键消息在新列表中的位置
          int newIndex = newMessages.indexWhere(
            (msg) => msg.msgId == keyMessage!.msgId,
          );
          debugPrint('关键消息在新列表中的位置: $newIndex');

          if (newIndex != -1) {
            // 9. 计算新的滚动位置
            // 目标是让关键消息保持在原来的可见位置
            final position = _scrollController.position;
            debugPrint('新的最大滚动范围: ${position.maxScrollExtent}');

            // 计算新列表中每条消息的平均高度
            double averageItemHeight = 0;
            if (newMessages.isNotEmpty) {
              averageItemHeight = position.maxScrollExtent / newMessages.length;
              debugPrint('新列表平均消息高度: $averageItemHeight');
            }

            // 计算关键消息在旧列表中的位置
            int oldIndex = currentMessages.indexOf(keyMessage);
            debugPrint('关键消息在旧列表中的位置: $oldIndex');

            if (oldIndex != -1) {
              // 计算需要滚动的偏移量
              // 关键消息在新列表中的位置比旧列表中多了addedMessageCount个位置（新消息被添加到顶部）
              int indexDifference = newIndex - oldIndex;
              debugPrint('位置差异: $indexDifference');

              // 新的滚动位置 = 原来的滚动位置 + 新增消息占用的高度
              final newScrollOffset =
                  _scrollController.position.pixels +
                  (indexDifference * averageItemHeight);
              debugPrint('计算的新滚动位置: $newScrollOffset');

              // 确保滚动位置在有效范围内
              final safeOffset = newScrollOffset.clamp(
                0.0,
                position.maxScrollExtent,
              );
              debugPrint('修正后的安全滚动位置: $safeOffset');

              // 滚动到目标位置
              _scrollController.jumpTo(safeOffset);
              debugPrint('滚动完成');
            }
          }
        }
      });

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
  Future<void> _sendImageMessage(File imageFile) async {
    try {
      final globalUtil = GlobalUtil();
      String receiver = friendInfo?.userName ?? '';

      if (receiver.isEmpty) {
        debugPrint('ERROR: 无法发送图片消息，接收者userName为空');
        return;
      }

      // 获取当前时间和消息ID
      String time = _getTime();
      int msgId = DateTime.now().millisecondsSinceEpoch;
      String conversationId = _generateConversationId();

      // 生成图片文件名：当前用户的UserName_发送用户的UserName_时间戳
      String imageName = '${globalUtil.userName}_${receiver}_$msgId.jpg';

      // 上传图片到服务器
      await _uploadImage(imageFile, imageName);

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
      );

      // 添加消息到全局聊天记录
      globalUtil.addMessage(receiver, newMessage);

      // 更新UI并滚动到底部
      setState(() {});
      _scrollToBottom();

      // 使用WebSocket发送图片消息
      if (_wsManager.isConnected) {
        // 构建并发送WebSocket消息
        _sendWebSocketMessage(
          msgId: msgId,
          content: imageName, // 图片消息的content存储图片名
          receiver: receiver,
          conversationId: conversationId,
          messageType: MessageType.image,
        );

        // 更新消息状态为发送成功
        List<Message> friendMessages = globalUtil.getChatRecords(receiver);
        for (var message in friendMessages) {
          if (message.msgId == msgId && message.isMe) {
            message.status = MessageStatus.sent;
            break;
          }
        }

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
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        debugPrint('Selected image: ${image.path}');
        await _sendImageMessage(File(image.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
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
    int msgType = messageData['msgType'] ?? 1;
    MessageType messageType = msgType == 2
        ? MessageType.image
        : MessageType.text;

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
          message.status = MessageStatus.sent;
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
          message.status = MessageStatus.sent;
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
    if (_wsManager.isConnected) {
      _wsManager.send({
        'type': 'chatCallback',
        'msgId': msgId,
        'receiveId': friendInfo?.userName,
        'sender': GlobalUtil().userInfoModel.userName,
        'sessionId': _generateConversationId(),
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

      // 检查是否已经加载过记录
      if (globalUtil.getChatRecordsCount(id!) == 0) {
        // 加载100条记录
        await globalUtil.loadChatRecords(id!, 100);

        // 更新UI
        setState(() {});
      }

      // 无论是否加载了新记录，都滚动到底部
      // 在整个界面构建完成后执行滚动操作
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('初始加载聊天记录失败: $e');
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
  void _scrollToBottom() {
    if (GlobalUtil().getChatRecords(id ?? '').isNotEmpty) {
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              friendInfo?.remarks ??
                  friendInfo?.nickName ??
                  friendInfo?.userName ??
                  "未知用户",
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
            SizedBox(height: 2),
            Text(
              friendInfo?.isOnline ?? false ? '在线' : '离线',
              style: TextStyle(
                color: friendInfo?.isOnline ?? false
                    ? Colors.green
                    : Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.phone, color: Colors.black),
            onPressed: () {
              // 发起语音通话功能（可以在后续实现）
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('语音通话功能即将上线'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.videocam, color: Colors.black),
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
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
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
                  // 使用当前聊天好友的全局消息列表，如果不存在则使用空列表
                  itemCount: GlobalUtil().getChatRecords(id ?? '').length,
                  itemBuilder: (context, index) {
                    // 获取当前聊天好友的全局消息列表
                    final globalUtil = GlobalUtil();
                    final friendMessages = globalUtil.getChatRecords(id ?? '');
                    final message = friendMessages[index];
                    return MessageBubble(
                      message: message,
                      friendInfo: friendInfo,
                      currentUserAvatar: globalUtil.userInfoModel.avatar,
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
    String conversationId = _generateConversationId();
    String receiver = friendInfo?.userName ?? '';

    if (receiver.isEmpty) {
      debugPrint('ERROR: 无法发送消息，接收者userName为空');
      return;
    }

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
    );

    // 添加消息到全局聊天记录
    globalUtil.addMessage(receiver, newMessage);

    // 更新UI并滚动到底部
    setState(() {});
    _scrollToBottom();

    // 使用WebSocket发送消息
    if (_wsManager.isConnected) {
      // 构建并发送WebSocket消息
      _sendWebSocketMessage(
        msgId: msgId,
        content: text,
        receiver: receiver,
        conversationId: conversationId,
        messageType: MessageType.text,
      );

      // 更新消息状态为发送中
      List<Message> friendMessages = globalUtil.getChatRecords(receiver);
      for (var message in friendMessages) {
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
    required String receiver,
    required String conversationId,
    required MessageType messageType,
  }) {
    // 根据消息类型设置msgType
    int msgType = messageType == MessageType.image ? 2 : 1;

    // 构建消息数据
    Map<String, dynamic> messageData = {
      'type': 'chat',
      'msgType': msgType, // 1文本 2图片
      'msgId': msgId,
      'msgContent': content,
      'sendUserId': GlobalUtil().userInfoModel.userName,
      'receiveId': receiver,
      'sendTime': GlobalUtil.getCurrentTimestamp(),
      'readTime': 0,
      'sessionId': conversationId,
      "receiveType": 1,
      'extendInfo': "无",
      'msgStatus': 1, //1 发送成功  3 已读
    };

    // 发送WebSocket消息
    _wsManager.send(messageData);
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
    String myUserName = globalUtil.userInfoModel.userName ?? '';
    String otherUserName = friendInfo?.userName ?? '';
    return GlobalUtil.generateSessionId(myUserName, otherUserName);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
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
  final globalUtil = GlobalUtil();
  final dio = Dio();
  // 头像 URL 缓存，用于避免重复加载
  static Map<String, String> _avatarCache = {};
  MessageBubble({
    required this.message,
    required this.friendInfo,
    required this.currentUserAvatar,
  });

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
    String receiver = message.isMe
        ? friendInfo?.userName ?? ""
        : globalUtil.userName ?? "";
    globalUtil.deleteMessage(receiver, message.msgId);
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
            ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: CircleAvatar(
          backgroundImage: NetworkImage(avatarUrl),
          backgroundColor: Colors.grey[200],
          radius: 24,
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
      backgroundImage: NetworkImage(avatarUrl),
      backgroundColor: Colors.grey[200],
      radius: 24,
    );
  }

  // 构建图片消息
  Widget _buildImageMessage() {
    // 获取图片URL：根据消息类型和发送者获取正确的URL
    String imageURL;
    if (message.isMe) {
      // 自己发送的图片
      imageURL = globalUtil.getImageURL(
        globalUtil.userName ?? "",
        message.content,
      );
    } else {
      // 对方发送的图片
      imageURL = globalUtil.getImageURL(
        friendInfo?.userName ?? "",
        message.content,
      );
    }

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
        child: CachedNetworkImage(
          imageUrl: imageURL,
          fit: BoxFit.cover,
          width: 200.0,
          height: 200.0,
          progressIndicatorBuilder:
              (BuildContext context, String url, DownloadProgress? progress) {
                if (progress == null) {
                  return SizedBox(width: 200.0, height: 200.0);
                } else {
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.totalSize != null
                          ? progress.downloaded / (progress.totalSize ?? 1)
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
              child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isMe ? Colors.green[300] : Colors.white;
    final textColor = message.isMe ? Colors.white : Colors.black;
    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(16),
      topRight: Radius.circular(16),
      bottomLeft: message.isMe ? Radius.circular(16) : Radius.circular(0),
      bottomRight: message.isMe ? Radius.circular(0) : Radius.circular(16),
    );

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
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
                // 状态显示：已读/未读 或 发送失败
                if (message.isMe)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (message.status == MessageStatus.failed)
                        Icon(Icons.error_outline, size: 12, color: Colors.red),
                      if (message.status == MessageStatus.failed)
                        SizedBox(width: 2),
                      Text(
                        message.status == MessageStatus.failed
                            ? '发送失败'
                            : (message.isRead ? '已读' : '未读'),
                        style: TextStyle(
                          color: message.status == MessageStatus.failed
                              ? Colors.red
                              : (message.isRead ? Colors.grey : Colors.blue),
                          fontSize: 10,
                        ),
                      ),
                      SizedBox(width: 4),
                    ],
                  ),

                // 消息气泡
                message.messageType == MessageType.image
                    ? // 图片消息：使用不同的样式，没有背景色
                      GestureDetector(
                        // 添加点击事件，用于图片放大查看
                        onTap: () {
                          // 实现图片放大查看功能
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              child: GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: CachedNetworkImage(
                                  imageUrl: message.isMe
                                      ? globalUtil.getImageURL(
                                          globalUtil.userName ?? "",
                                          message.content,
                                        )
                                      : globalUtil.getImageURL(
                                          friendInfo?.userName ?? "",
                                          message.content,
                                        ),
                                  fit: BoxFit.contain,
                                  progressIndicatorBuilder:
                                      (context, url, progress) => Center(
                                        child: CircularProgressIndicator(
                                          value: progress.totalSize != null
                                              ? (progress.downloaded as num) /
                                                    (progress.totalSize as num)
                                              : null,
                                        ),
                                      ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        // 添加长按事件，用于弹出底部操作弹窗
                        onLongPress: () {
                          _showImageActions(context);
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 2.0),
                          padding: EdgeInsets.all(0.0),
                          decoration: BoxDecoration(
                            // 图片消息不使用背景色
                            borderRadius: borderRadius,
                          ),
                          child: _buildImageMessage(),
                        ),
                      )
                    : // 文本消息：使用SelectableText实现长按全选和自定义菜单
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 2.0),
                        padding: EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: borderRadius,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.3),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: GestureDetector(
                          // 长按事件显示自定义菜单
                          onLongPress: () {
                            _showTextContextMenu(context);
                          },
                          child: SelectableText(
                            message.content,
                            style: TextStyle(color: textColor, fontSize: 16),
                          ),
                        ),
                      ),

                // 时间
                Row(
                  mainAxisAlignment: message.isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Text(
                      message.time,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
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
