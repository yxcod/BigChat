import 'package:flutter/material.dart';
import 'dart:async';
import '../../model/conversationModel.dart';
import '../../api/getConversationAPI.dart';
import '../../api/getChatMessagesAPI.dart';
import '../../utils/Gloabl.dart';
import '../../model/friendInfoModel.dart';
import '../../model/messageModel.dart';

class Chatpage extends StatefulWidget {
  final List<Chat> chatList;
  final Function(int)? onUnreadCountChanged;

  Chatpage({Key? key, required this.chatList, this.onUnreadCountChanged})
    : super(key: key);

  @override
  _ChatpageState createState() => _ChatpageState();
}

class _ChatpageState extends State<Chatpage> {
  final List<Chat> _chats = [
    Chat(
      name: '张三',
      avatar: 'https://via.placeholder.com/40',
      lastMessage: '你好！',
      time: '10:30',
      unreadCount: 2,
      userName: 'zhangsan',
    ),
    Chat(
      name: '李四',
      avatar: 'https://via.placeholder.com/40',
      lastMessage: '最近怎么样？',
      time: '昨天',
      unreadCount: 0,
      userName: 'lisi',
    ),
    Chat(
      name: '王五',
      avatar: 'https://via.placeholder.com/40',
      lastMessage: '谢谢！',
      time: '前天',
      unreadCount: 1,
      userName: 'wangwu',
    ),
    Chat(
      name: '赵六',
      avatar: 'https://via.placeholder.com/40',
      lastMessage: '好的，明天见',
      time: '3天前',
      unreadCount: 0,
      userName: 'zhaoliu',
    ),
    Chat(
      name: '孙七',
      avatar: 'https://via.placeholder.com/40',
      lastMessage: '收到',
      time: '1周前',
      unreadCount: 0,
      userName: 'sunqi',
    ),
  ];

  Timer? _fetchTimer;
  GlobalUtil globalUtil = GlobalUtil();
  bool _wasChatting = false;

  @override
  void initState() {
    super.initState();
    // 延迟到构建完成后执行需要setState的操作
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyUnreadCountChanged();
      // 页面加载时获取会话列表
      fetchConversations();
      // 启动定期获取会话列表的定时器
      _startFetchTimer();
    });

    // 注册未读消息数变化的回调
    globalUtil.onUnreadCountChanged = (userName, count) {
      // 确保在回调中不会在构建过程中触发setState
      if (mounted) {
        _updateChatUnreadCount(userName, count);
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听isChatting状态变化
    bool currentIsChatting = globalUtil.isChatting ?? false;
    if (currentIsChatting != _wasChatting) {
      _wasChatting = currentIsChatting;
      if (currentIsChatting) {
        // 进入聊天界面，停止定时器
        _stopFetchTimer();
      } else {
        // 离开聊天界面，启动定时器
        _startFetchTimer();
      }
    }
  }

  @override
  void dispose() {
    // 清理定时器
    _stopFetchTimer();
    super.dispose();
  }

  // 启动定时器，每秒获取一次会话列表
  void _startFetchTimer() {
    if (_fetchTimer != null && _fetchTimer!.isActive) {
      return;
    }

    _fetchTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && !(globalUtil.isChatting ?? false)) {
        fetchConversations();
      }
    });
  }

  // 停止定时器
  void _stopFetchTimer() {
    if (_fetchTimer != null) {
      _fetchTimer!.cancel();
      _fetchTimer = null;
    }
  }

  void updateChat(String userName, Chat chat) {
    setState(() {
      final index = _chats.indexWhere(
        (element) => element.userName == userName,
      );
      if (index != -1) {
        // 存在则更新
        _chats[index] = chat;
      } else {
        // 不存在则插入
        _chats.add(chat);
      }
      _notifyUnreadCountChanged();
    });
  }

  void removeChat(String userName) {
    setState(() {
      _chats.removeWhere((element) => element.userName == userName);
      _notifyUnreadCountChanged();
    });
  }

  void _updateChatUnreadCount(String userName, int count) {
    setState(() {
      final index = _chats.indexWhere(
        (element) => element.userName == userName,
      );
      if (index != -1) {
        // 更新未读消息数
        final updatedChat = Chat(
          name: _chats[index].name,
          avatar: _chats[index].avatar,
          lastMessage: _chats[index].lastMessage,
          time: _chats[index].time,
          unreadCount: count,
          userName: _chats[index].userName,
        );
        _chats[index] = updatedChat;
        _notifyUnreadCountChanged();
      }
    });
  }

  int _calculateTotalUnreadCount() {
    return _chats.fold(0, (sum, chat) => sum + chat.unreadCount);
  }

  void _notifyUnreadCountChanged() {
    final totalUnreadCount = _calculateTotalUnreadCount();
    widget.onUnreadCountChanged?.call(totalUnreadCount);
  }

  List<Chat> _convertToChatList(List<ConversationModel> conversations) {
    final globalUtil = GlobalUtil();
    final currentUserName = globalUtil.userName;
    final friendList = globalUtil.userInfoModel.friendListData ?? [];

    return conversations.map((conversation) {
      // 确定目标用户的 userName
      final targetUserName = conversation.user1Id == currentUserName
          ? conversation.user2Id
          : conversation.user1Id;

      // 查找好友信息
      final friend = friendList.firstWhere(
        (f) => f.userName == targetUserName,
        orElse: () => FriendInfoModel.formJSON({'userName': targetUserName}),
      );

      // 格式化时间
      final formattedTime = GlobalUtil.formatTimestamp(conversation.updateTime);
      String avatarURL = globalUtil.getImageURL(targetUserName, "head.jpg");
      // 同时检查null和空字符串
      // String testnickName = (friend.nickName?.isEmpty ?? true)
      //     ? "错误"
      //     : friend.nickName!;
      // debugPrint("testNickName === $testnickName");

      // 创建 Chat 对象
      return Chat(
        name: (friend.remarks?.isEmpty ?? true)
            ? (friend.nickName?.isEmpty ?? true)
                  ? (friend.userName?.isEmpty ?? true)
                        ? '未知用户'
                        : friend.userName!
                  : friend.nickName!
            : friend.remarks!,
        avatar: avatarURL,
        lastMessage: conversation.lastMsg ?? '',
        time: formattedTime.substring(11, 16), // 只显示时分
        unreadCount: conversation.unreadCount,
        userName: targetUserName,
      );
    }).toList();
  }

  Future<void> fetchConversations() async {
    try {
      final globalUtil = GlobalUtil();
      final currentUserName = globalUtil.userName;
      if (currentUserName == null) {
        debugPrint('当前用户未登录');
        return;
      }

      // 调用 API 获取会话列表
      final conversations = await getConversationApi(currentUserName);

      // 转换为 Chat 列表并更新 UI
      final chatList = _convertToChatList(conversations);

      // 检查是否有新的会话ID添加
      final existingUserNames = _chats.map((chat) => chat.userName).toSet();
      final newUserNames = chatList.map((chat) => chat.userName).toSet();
      final addedUserNames = newUserNames.difference(existingUserNames);
      final hasNewConversationsAdded = addedUserNames.isNotEmpty;

      setState(() {
        _chats.clear();
        _chats.addAll(chatList);
        _notifyUnreadCountChanged();
      });

      // 只在以下情况加载聊天记录：
      // 1. 有新的会话添加（会话列表长度增加）
      // 2. 有新的会话ID添加
      if (hasNewConversationsAdded) {
        // 筛选出新增的会话
        final addedConversations = conversations.where((conversation) {
          final targetUserName = conversation.user1Id == currentUserName
              ? conversation.user2Id
              : conversation.user1Id;
          return addedUserNames.contains(targetUserName);
        }).toList();

        // 只为新增的会话加载最近100条聊天记录
        await _loadChatRecordsForConversations(
          addedConversations,
          currentUserName,
        );
      }
    } catch (e) {
      debugPrint('获取会话列表失败：$e');
    }
  }

  // 为每个会话加载最近100条聊天记录
  Future<void> _loadChatRecordsForConversations(
    List<ConversationModel> conversations,
    String currentUserName,
  ) async {
    try {
      final globalUtil = GlobalUtil();
      debugPrint('开始为${conversations.length}个会话加载聊天记录...');

      // 遍历所有会话
      for (var conversation in conversations) {
        // 确定目标用户的 userName
        final targetUserName = conversation.user1Id == currentUserName
            ? conversation.user2Id
            : conversation.user1Id;

        // 生成会话ID
        final sessionId = GlobalUtil.generateSessionId(
          currentUserName,
          targetUserName,
        );

        try {
          // 获取最近100条聊天记录
          final messageModels = await getChatMessagesApi(
            conversationId: sessionId,
            count: 100,
          );

          // 转换为Message对象并保存到_chatRecords
          final messages = messageModels.map((model) {
            return Message(
              msgId: model.msgId ?? 0,
              content: model.content ?? '',
              isMe: model.senderName == currentUserName,
              time: model.timestamp != null
                  ? GlobalUtil.formatTimestamp(model.timestamp!)
                  : '',
              isRead: true,
              conversationId: model.conversationId ?? '',
              messageType: model.messageType ?? MessageType.text,
              status: model.messageStatus ?? MessageStatus.sent,
            );
          }).toList();

          // 保存到_chatRecords
          globalUtil.clearChatRecords(targetUserName);
          messages.forEach((msg) {
            globalUtil.addMessage(targetUserName, msg);
          });

          debugPrint('成功为$targetUserName加载${messages.length}条聊天记录');
        } catch (e) {
          debugPrint('为$targetUserName加载聊天记录失败：$e');
          // 继续处理其他会话，不中断整个流程
        }
      }

      debugPrint('所有会话聊天记录加载完成');
    } catch (e) {
      debugPrint('加载会话聊天记录失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        toolbarHeight: 70,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: '搜索',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(top: 8),
        child: ListView.builder(
          itemCount: _chats.length,
          itemBuilder: (context, index) {
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(_chats[index].avatar),
                backgroundColor: Colors.grey[200],
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _chats[index].name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ), // 确保文本颜色可见
                  ),
                  Text(
                    _chats[index].time,
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
              subtitle: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _chats[index].lastMessage,
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_chats[index].unreadCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _chats[index].unreadCount.toString(),
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
              onTap: () {
                //String testName = _chats[index].name;
                //String testUserName = _chats[index].userName;
                //debugPrint("聊天项点击：name=$testName, userName=$testUserName");
                // 使用命名路由跳转到聊天详情页面
                Navigator.pushNamed(
                  context,
                  '/chatDialog',
                  arguments: _chats[index].userName,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// 聊天数据模型
class Chat {
  final String name;
  final String avatar;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final String userName;

  Chat({
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.userName,
  });
}
