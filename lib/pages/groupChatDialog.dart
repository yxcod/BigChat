import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/Gloabl.dart';
import '../model/friendInfoModel.dart';
import '../utils/WebSocketManager.dart';
import '../model/messageModel.dart';
import 'videoCallPage.dart';
import '../utils/http.dart';

class GroupChatDialogPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<FriendInfoModel> groupMembers;

  GroupChatDialogPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupMembers,
  }) : super(key: key);

  @override
  _GroupChatDialogPageState createState() => _GroupChatDialogPageState();
}

class _GroupChatDialogPageState extends State<GroupChatDialogPage> {
  WebSocketManager _wsManager = WebSocketManager();
  FocusNode _textFieldFocusNode = FocusNode();
  ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  List<Map<String, dynamic>> _messageReadStatus = []; // 存储每条消息的已读状态

  @override
  void initState() {
    super.initState();

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
        globalUtil.getChatRecords(widget.groupId),
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

      // 调用API加载更多记录
      await globalUtil.loadMoreChatRecords(widget.groupId);

      // 获取新的聊天记录列表
      List<Message> newMessages = globalUtil.getChatRecords(widget.groupId);

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
      String conversationId = widget.groupId;

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
      );

      // 添加消息到全局聊天记录
      globalUtil.addMessage(widget.groupId, newMessage);

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
        List<Message> groupMessages = globalUtil.getChatRecords(widget.groupId);
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
    if (message is Map<String, dynamic>) {
      String messageType = message['type'] ?? '';

      switch (messageType) {
        case 'chat':
          _handleChatMessage(message);
          break;
        case 'chatCallback':
          _handleChatCallback(message);
          break;
        case 'videoCallInvite':
          _handleVideoCallInvite(message);
          break;
        case 'videoCallAccept':
          _handleVideoCallAccept(message);
          break;
        case 'videoCallReject':
          _handleVideoCallReject(message);
          break;
        case 'videoCallHangup':
          _handleVideoCallHangup(message);
          break;
      }
    }
  }

  // 处理聊天消息
  void _handleChatMessage(Map<String, dynamic> messageData) {
    final globalUtil = GlobalUtil();
    String sender = messageData['sendUserId'] ?? '';
    String content = messageData['msgContent'] ?? '';
    int msgId = messageData['msgId'] ?? 0;
    int msgType = messageData['msgType'] ?? 1;
    String sendTime = _formatTimestamp(messageData['sendTime'] ?? 0);

    if (sender.isNotEmpty && content.isNotEmpty) {
      // 检查消息是否已存在
      List<Message> existingMessages = globalUtil.getChatRecords(
        widget.groupId,
      );
      bool messageExists = existingMessages.any((msg) => msg.msgId == msgId);

      if (!messageExists) {
        // 创建新消息
        Message newMessage = Message(
          msgId: msgId,
          content: content,
          isMe: sender == globalUtil.userName,
          time: sendTime,
          isRead: false,
          conversationId: widget.groupId,
          messageType: msgType == 2 ? MessageType.image : MessageType.text,
          status: MessageStatus.sent,
        );

        // 添加消息到全局聊天记录
        globalUtil.addMessage(widget.groupId, newMessage);

        // 更新UI并滚动到底部
        setState(() {});
        _scrollToBottom();

        // 发送已读确认
        _sendReadAck(msgId);
      }
    }
  }

  // 处理聊天回调
  void _handleChatCallback(Map<String, dynamic> messageData) {
    final globalUtil = GlobalUtil();
    int msgId = messageData['msgId'] ?? 0;
    String status = messageData['status'] ?? '';
    String sender = messageData['sender'] ?? '';

    // 更新消息状态
    List<Message> groupMessages = globalUtil.getChatRecords(widget.groupId);
    for (var message in groupMessages) {
      if (message.msgId == msgId) {
        if (status == 'success' && message.isMe) {
          message.status = MessageStatus.sent;
        } else if (status == 'failed' && message.isMe) {
          message.status = MessageStatus.failed;
        } else if (status == 'read' && !message.isMe) {
          // 更新消息已读状态
          message.isRead = true;
          // 更新消息的已读人数
          _updateMessageReadStatus(msgId, sender);
        }
        break;
      }
    }

    // 更新UI
    setState(() {});
  }

  // 更新消息的已读状态
  void _updateMessageReadStatus(int msgId, String reader) {
    final msgStatusIndex = _messageReadStatus.indexWhere(
      (status) => status['msgId'] == msgId,
    );
    if (msgStatusIndex != -1) {
      final msgStatus = _messageReadStatus[msgStatusIndex];
      List<dynamic> readMembers = msgStatus['readMembers'] ?? [];
      List<dynamic> unreadMembers = msgStatus['unreadMembers'] ?? [];

      if (!readMembers.contains(reader)) {
        readMembers.add(reader);
        unreadMembers.remove(reader);

        _messageReadStatus[msgStatusIndex] = {
          ...msgStatus,
          'readMembers': readMembers,
          'unreadMembers': unreadMembers,
          'readCount': readMembers.length,
          'unreadCount': unreadMembers.length,
        };
      }
    }
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
  void _sendReadAck(int msgId) {
    if (_wsManager.isConnected) {
      _wsManager.send({
        'type': 'chatCallback',
        'msgId': msgId,
        'receiveId': widget.groupId,
        'sender': GlobalUtil().userName,
        'sessionId': widget.groupId,
        'status': 'read',
      });
    }
  }

  // 确保WebSocket已连接
  void _ensureWebSocketConnected() {
    // 无论是否已经连接，都更新回调函数
    _wsManager.connect(
      '${GlobalUtil().baseWebSocketURL}/api/chat?userName=${GlobalUtil().userName}',
      onStatusChanged: (status) {
        debugPrint('WebSocket状态: $status');
      },
      onMessageReceived: (message) {
        _handleWebSocketMessage(message);
      },
      onError: (error) {
        debugPrint('WebSocket错误: $error');
      },
    );
  }

  // 滚动到底部的辅助方法
  void _scrollToBottom() {
    if (GlobalUtil().getChatRecords(widget.groupId).isNotEmpty) {
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
        title: Center(
          child: Text(
            widget.groupName,
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
                  'channelName': widget.groupId,
                  'token': token,
                  'time': DateTime.now().millisecondsSinceEpoch,
                });
              }

              // 使用groupId作为频道名称
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      VideoCallPage(channelName: widget.groupId, token: token),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // 进入群管理页面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupManagePage(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                    groupMembers: widget.groupMembers,
                  ),
                ),
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
                  itemCount: GlobalUtil().getChatRecords(widget.groupId).length,
                  itemBuilder: (context, index) {
                    // 获取当前聊天群的全局消息列表
                    final globalUtil = GlobalUtil();
                    final groupMessages = globalUtil.getChatRecords(
                      widget.groupId,
                    );
                    final message = groupMessages[index];
                    // 获取消息的未读人数
                    int unreadCount = widget.groupMembers.length - 1; // 默认值
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
                      groupMembers: widget.groupMembers,
                      currentUserAvatar: globalUtil.userInfoModel.avatar,
                      onReadStatusTap: () {
                        _showReadStatusList(message.msgId);
                      },
                      unreadCount: unreadCount,
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
    String conversationId = widget.groupId;

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
    globalUtil.addMessage(widget.groupId, newMessage);

    // 初始化消息的已读状态
    _messageReadStatus.add({
      'msgId': msgId,
      'readCount': 0,
      'unreadCount': widget.groupMembers.length - 1, // 减去自己
      'readMembers': [],
      'unreadMembers': widget.groupMembers
          .where((member) => member.userName != globalUtil.userName)
          .map((member) => member.userName)
          .toList(),
    });

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
      List<Message> groupMessages = globalUtil.getChatRecords(widget.groupId);
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
    required String receiver,
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

    // 发送WebSocket消息
    _wsManager.send(messageData);
  }

  String _getTime() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}:${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // 将毫秒级时间戳转换为UI显示的时间格式 (MM:dd HH:MM)
  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dateTime.month.toString().padLeft(2, '0')}:${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 显示已读状态列表
  void _showReadStatusList(int msgId) {
    // 查找消息的已读状态
    final msgStatus = _messageReadStatus.firstWhere(
      (status) => status['msgId'] == msgId,
      orElse: () => {
        'msgId': msgId,
        'readCount': 0,
        'unreadCount': widget.groupMembers.length - 1,
        'readMembers': [],
        'unreadMembers': widget.groupMembers
            .where((member) => member.userName != GlobalUtil().userName)
            .map((member) => member.userName)
            .toList(),
      },
    );

    // 显示已读/未读成员列表
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已读 (${msgStatus['readCount']})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: msgStatus['readMembers'].length,
                  itemBuilder: (context, index) {
                    final memberName = msgStatus['readMembers'][index];
                    final member = widget.groupMembers.firstWhere(
                      (m) => m.userName == memberName,
                      orElse: () => FriendInfoModel(
                        userName: memberName,
                        nickName: memberName,
                        remarks: '',
                        avatar: '',
                        signature: '',
                        isOnline: false,
                      ),
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(member.nickName?.substring(0, 1) ?? '?'),
                      ),
                      title: Text(member.nickName ?? member.userName ?? '未知'),
                    );
                  },
                ),
              ),
              SizedBox(height: 10),
              Text(
                '未读 (${msgStatus['unreadCount']})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: msgStatus['unreadMembers'].length,
                  itemBuilder: (context, index) {
                    final memberName = msgStatus['unreadMembers'][index];
                    final member = widget.groupMembers.firstWhere(
                      (m) => m.userName == memberName,
                      orElse: () => FriendInfoModel(
                        userName: memberName,
                        nickName: memberName,
                        remarks: '',
                        avatar: '',
                        signature: '',
                        isOnline: false,
                      ),
                    );
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(member.nickName?.substring(0, 1) ?? '?'),
                        backgroundColor: Colors.grey[300],
                      ),
                      title: Text(
                        member.nickName ?? member.userName ?? '未知',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
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

class GroupMessageBubble extends StatelessWidget {
  final Message message;
  final List<FriendInfoModel> groupMembers;
  final String? currentUserAvatar;
  final VoidCallback onReadStatusTap;
  final int unreadCount;
  final globalUtil = GlobalUtil();
  final dio = Dio();

  GroupMessageBubble({
    required this.message,
    required this.groupMembers,
    required this.currentUserAvatar,
    required this.onReadStatusTap,
    required this.unreadCount,
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
              padding: EdgeInsets.only(
                left: message.messageType == MessageType.text ? 60.0 : 70.0,
                bottom: 4.0,
              ),
              child: Text(
                _getSenderName(),
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                Container(
                  margin: EdgeInsets.only(right: 8.0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: _getSenderAvatar() != null
                        ? NetworkImage(_getSenderAvatar()!)
                        : null,
                    child: _getSenderAvatar() == null
                        ? Text(
                            _getSenderName().substring(0, 1),
                            style: TextStyle(fontSize: 16),
                          )
                        : null,
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
                    backgroundImage: currentUserAvatar != null
                        ? NetworkImage(currentUserAvatar!)
                        : null,
                    child: currentUserAvatar == null
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
    // 这里简化处理，实际应该从消息中获取发送者ID，然后查找对应的群成员信息
    if (message.isMe) {
      return globalUtil.userName ?? '我';
    } else {
      // 由于Message类中没有存储发送者信息，这里返回第一个群成员的名称
      // 实际应用中应该从消息中获取发送者ID并查找对应的群成员
      return groupMembers.isNotEmpty
          ? (groupMembers[0].nickName ?? groupMembers[0].userName ?? '未知')
          : '未知';
    }
  }

  // 获取发送者头像
  String? _getSenderAvatar() {
    // 这里简化处理，实际应该从消息中获取发送者ID，然后查找对应的群成员信息
    if (!message.isMe && groupMembers.isNotEmpty) {
      return groupMembers[0].avatar;
    }
    return null;
  }
}

class GroupManagePage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<FriendInfoModel> groupMembers;

  GroupManagePage({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupMembers,
  }) : super(key: key);

  @override
  _GroupManagePageState createState() => _GroupManagePageState();
}

class _GroupManagePageState extends State<GroupManagePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('群管理'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // 群名称
          ListTile(
            title: Text('群名称'),
            subtitle: Text(widget.groupName),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              // 修改群名称
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('修改群名称功能开发中'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          Divider(),
          // 群成员
          ListTile(
            title: Text('群成员'),
            subtitle: Text('${widget.groupMembers.length}人'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              // 查看群成员
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GroupMembersPage(groupMembers: widget.groupMembers),
                ),
              );
            },
          ),
          Divider(),
          // 群公告
          ListTile(
            title: Text('群公告'),
            subtitle: Text('未设置'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              // 修改群公告
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('修改群公告功能开发中'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          Divider(),
          // 退出群聊
          ListTile(
            title: Text('退出群聊', style: TextStyle(color: Colors.red)),
            onTap: () {
              // 退出群聊
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('退出群聊'),
                    content: Text('确定要退出该群聊吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context); // 退出群管理页面
                          Navigator.pop(context); // 退出群聊页面
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已退出群聊'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Text('确定', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class GroupMembersPage extends StatelessWidget {
  final List<FriendInfoModel> groupMembers;

  GroupMembersPage({Key? key, required this.groupMembers}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('群成员'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView.builder(
        itemCount: groupMembers.length,
        itemBuilder: (context, index) {
          final member = groupMembers[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: member.avatar != null
                  ? NetworkImage(member.avatar!)
                  : null,
              child: member.avatar == null
                  ? Text(member.nickName?.substring(0, 1) ?? '?')
                  : null,
            ),
            title: Text(member.nickName ?? member.userName ?? '未知'),
            subtitle: Text(member.userName ?? ''),
          );
        },
      ),
    );
  }
}
