import 'package:flutter/material.dart';
import 'dart:async';
import '../../model/conversationModel.dart';
import '../../api/getConversationAPI.dart';
import '../../api/getChatMessagesAPI.dart';
import '../../utils/gloabl.dart';
import '../../model/friendInfoModel.dart';
import '../../model/messageModel.dart';
import '../../model/groupConversationModel.dart';
import '../../api/groupChatRecordAPI.dart';
import '../../api/getGroupInfoAPI.dart';
import '../../api/getGroupMemberAPI.dart';
import '../../model/groupInfoModel.dart';
import '../../model/groupMemberModel.dart';

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
    // Chat(
    //   name: '赵六',
    //   avatar: 'https://via.placeholder.com/40',
    //   lastMessage: '好的，明天见',
    //   time: '3天前',
    //   unreadCount: 0,
    //   userName: 'zhaoliu',
    // ),
    // Chat(
    //   name: '孙七',
    //   avatar: 'https://via.placeholder.com/40',
    //   lastMessage: '收到',
    //   time: '1周前',
    //   unreadCount: 0,
    //   userName: 'sunqi',
    // ),
  ];

  Timer? _fetchTimer;
  GlobalUtil globalUtil = GlobalUtil();
  bool _wasChatting = false;
  // 头像 URL 缓存，用于避免重复加载
  Map<String, String> _avatarCache = {};

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

  Future<List<Chat>> _convertToChatList(
    List<ConversationModel> conversations,
    List<GroupConversationModel> groupConversations,
  ) async {
    final globalUtil = GlobalUtil();
    final currentUserName = globalUtil.userName;
    final friendList = globalUtil.userInfoModel.friendListData ?? [];
    final List<Chat> chatList = [];

    // 转换单聊会话
    for (final conversation in conversations) {
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
      // 使用好友的 avatar 字段作为头像文件名，实现缓存机制
      String avatarName = friend.avatar ?? "head.jpg";
      String newAvatarUrl = globalUtil.getImageURL(targetUserName, avatarName);

      // 检查缓存中是否已有该用户的头像，并且 URL 是否相同
      String avatarURL;
      if (_avatarCache.containsKey(targetUserName)) {
        String cachedUrl = _avatarCache[targetUserName]!;
        if (cachedUrl == newAvatarUrl) {
          // URL 相同，使用缓存的头像 URL
          avatarURL = cachedUrl;
        } else {
          // URL 不同，使用新的头像 URL 并更新缓存
          avatarURL = newAvatarUrl;
          _avatarCache[targetUserName] = newAvatarUrl;
        }
      } else {
        // 缓存中没有，使用新的头像 URL 并加入缓存
        avatarURL = newAvatarUrl;
        _avatarCache[targetUserName] = newAvatarUrl;
      }

      // 创建 Chat 对象
      chatList.add(
        Chat(
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
          isGroup: false,
        ),
      );
    }

    // 转换群聊会话
    try {
      // 获取所有群聊信息
      final allGroups = await getGroups(currentUserName!);

      for (final groupConversation in groupConversations) {
        try {
          // 查找对应的群聊信息
          final groupInfo = allGroups.firstWhere(
            (g) => g.groupId == groupConversation.groupId,
            orElse: () => GroupInfoModel(
              groupId: groupConversation.groupId,
              groupName: '未知群聊',
              creatorId: '',
            ),
          );
          final groupIdStr = groupConversation.groupId.toString();

          // 格式化时间
          final formattedTime = GlobalUtil.formatTimestamp(
            groupConversation.updateTime,
          );

          // 构建群聊头像 URL
          String avatarName = groupInfo.groupAvatar;
          String newAvatarUrl = globalUtil.getImageURL(groupIdStr, avatarName);

          // 检查缓存中是否已有该群聊的头像，并且 URL 是否相同
          String avatarURL;
          if (_avatarCache.containsKey(groupIdStr)) {
            String cachedUrl = _avatarCache[groupIdStr]!;
            if (cachedUrl == newAvatarUrl) {
              // URL 相同，使用缓存的头像 URL
              avatarURL = cachedUrl;
            } else {
              // URL 不同，使用新的头像 URL 并更新缓存
              avatarURL = newAvatarUrl;
              _avatarCache[groupIdStr] = newAvatarUrl;
            }
          } else {
            // 缓存中没有，使用新的头像 URL 并加入缓存
            avatarURL = newAvatarUrl;
            _avatarCache[groupIdStr] = newAvatarUrl;
          }

          // 查找最后发送者的名称
          String? lastSenderName;
          if (groupConversation.lastSenderId.isNotEmpty) {
            // 如果发送者是自身，显示为"我"
            if (groupConversation.lastSenderId == currentUserName) {
              lastSenderName = '我';
            } else {
              try {
                // 获取群成员列表
                final groupMembers = await getGroupMembers(
                  groupConversation.groupId,
                );
                // 从群成员列表中查找发送者的群昵称
                final senderMember = groupMembers.firstWhere(
                  (member) => member.userId == groupConversation.lastSenderId,
                  orElse: () => GroupMemberModel(
                    userId: groupConversation.lastSenderId,
                    groupNickName: '',
                    avatar: '',
                  ),
                );
                // 如果有群昵称，使用群昵称；否则使用用户名
                if (senderMember.groupNickName.isNotEmpty) {
                  lastSenderName = senderMember.groupNickName;
                } else {
                  // 如果没有群昵称，从好友列表中查找
                  final sender = friendList.firstWhere(
                    (f) => f.userName == groupConversation.lastSenderId,
                    orElse: () => FriendInfoModel.formJSON({
                      'userName': groupConversation.lastSenderId,
                    }),
                  );
                  lastSenderName = (sender.remarks?.isEmpty ?? true)
                      ? (sender.nickName?.isEmpty ?? true)
                            ? sender.userName!
                            : sender.nickName!
                      : sender.remarks!;
                }
              } catch (e) {
                debugPrint('获取群成员信息失败：$e');
                // 如果获取群成员失败，从好友列表中查找
                final sender = friendList.firstWhere(
                  (f) => f.userName == groupConversation.lastSenderId,
                  orElse: () => FriendInfoModel.formJSON({
                    'userName': groupConversation.lastSenderId,
                  }),
                );
                lastSenderName = (sender.remarks?.isEmpty ?? true)
                    ? (sender.nickName?.isEmpty ?? true)
                          ? sender.userName!
                          : sender.nickName!
                    : sender.remarks!;
              }
            }
          }

          // 创建群聊 Chat 对象
          chatList.add(
            Chat(
              name: groupInfo.groupName,
              avatar: avatarURL,
              lastMessage: groupConversation.lastMsg,
              time: formattedTime.substring(11, 16), // 只显示时分
              unreadCount: groupConversation.unreadCount,
              userName: groupIdStr,
              isGroup: true,
              lastSenderName: lastSenderName,
            ),
          );
        } catch (e) {
          debugPrint('转换群聊会话失败：$e');
          // 继续处理其他群聊会话，不中断整个流程
        }
      }
    } catch (e) {
      debugPrint('获取群聊信息失败：$e');
      // 继续处理，不中断整个流程
    }

    // 按更新时间排序，最新的在前面
    chatList.sort((a, b) {
      // 这里简化处理，实际应该根据会话的更新时间排序
      // 由于我们没有在 Chat 对象中存储更新时间，这里暂时不做排序
      return 0;
    });

    return chatList;
  }

  Future<void> fetchConversations() async {
    try {
      final globalUtil = GlobalUtil();
      final currentUserName = globalUtil.userName;
      if (currentUserName == null) {
        debugPrint('当前用户未登录');
        return;
      }

      // 调用 API 获取单聊会话列表
      final conversations = await getConversationApi(currentUserName);
      // 调用 API 获取群聊会话列表
      final groupConversations = await getGroupConversations(currentUserName);

      // 转换为 Chat 列表并更新 UI
      final chatList = await _convertToChatList(
        conversations,
        groupConversations,
      );

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
        // 筛选出新增的单聊会话
        final addedConversations = conversations.where((conversation) {
          final targetUserName = conversation.user1Id == currentUserName
              ? conversation.user2Id
              : conversation.user1Id;
          return addedUserNames.contains(targetUserName);
        }).toList();

        // 只为新增的单聊会话加载最近100条聊天记录
        await _loadChatRecordsForConversations(
          addedConversations,
          currentUserName,
        );

        // 筛选出新增的群聊会话
        final addedGroupConversations = groupConversations.where((
          conversation,
        ) {
          final groupIdStr = conversation.groupId.toString();
          return addedUserNames.contains(groupIdStr);
        }).toList();

        // 只为新增的群聊会话加载最近100条聊天记录
        await _loadGroupChatRecordsForConversations(
          addedGroupConversations,
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

  // 为每个群聊会话加载最近100条聊天记录
  Future<void> _loadGroupChatRecordsForConversations(
    List<GroupConversationModel> groupConversations,
    String currentUserName,
  ) async {
    try {
      final globalUtil = GlobalUtil();
      debugPrint('开始为${groupConversations.length}个群聊会话加载聊天记录...');

      // 遍历所有群聊会话
      for (var groupConversation in groupConversations) {
        final groupId = groupConversation.groupId;
        final groupIdStr = groupId.toString();

        try {
          // 获取最近100条群聊记录
          final groupMessageModel = await getGroupChatRecord(groupId, 100);

          // 转换为Message对象并保存到_chatRecords
          final messages = groupMessageModel.messages.map((model) {
            // 转换消息类型：0 -> text, 1 -> image
            MessageType messageType;
            switch (model.msgType) {
              case 1:
                messageType = MessageType.text;
                break;
              case 2:
                messageType = MessageType.image;
                break;
              default:
                messageType = MessageType.text;
                break;
            }

            return Message(
              msgId: model.msgId,
              content: model.msgContent,
              isMe: model.senderId == currentUserName,
              time: GlobalUtil.formatTimestamp(model.sendTime),
              isRead: true,
              conversationId: groupIdStr,
              messageType: messageType,
              status: MessageStatus.sent, // 简化处理，使用默认值
              senderId: model.senderId,
            );
          }).toList();

          // 保存到_chatRecords
          globalUtil.clearChatRecords(groupIdStr);
          messages.forEach((msg) {
            globalUtil.addMessage(groupIdStr, msg);
          });

          debugPrint('成功为群聊$groupId加载${messages.length}条聊天记录');
        } catch (e) {
          debugPrint('为群聊$groupId加载聊天记录失败：$e');
          // 继续处理其他群聊会话，不中断整个流程
        }
      }

      debugPrint('所有群聊会话聊天记录加载完成');
    } catch (e) {
      debugPrint('加载群聊会话聊天记录失败：$e');
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
                    child: _chats[index].isGroup
                        ? Text(
                            _chats[index].lastSenderName != null
                                ? '${_chats[index].lastSenderName}: ${_chats[index].lastMessage}'
                                : _chats[index].lastMessage,
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          )
                        : Text(
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
                if (_chats[index].isGroup) {
                  // 跳转到群聊对话框页面
                  Navigator.pushNamed(
                    context,
                    '/groupChatDialog',
                    arguments: {
                      'groupId': _chats[index].userName,
                      'groupName': _chats[index].name,
                    },
                  );
                } else {
                  // 跳转到单聊对话框页面
                  Navigator.pushNamed(
                    context,
                    '/chatDialog',
                    arguments: _chats[index].userName,
                  );
                }
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
  final bool isGroup; // 是否为群聊
  final String? lastSenderName; // 群聊最后一条消息的发送者名称

  Chat({
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.userName,
    this.isGroup = false,
    this.lastSenderName,
  });
}
