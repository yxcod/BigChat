import 'package:flutter/material.dart';
import 'dart:async';
import '../../model/conversationModel.dart';
import '../../api/getConversationAPI.dart';
import '../../utils/gloabl.dart';
import '../../model/friendInfoModel.dart';
import '../../model/messageModel.dart';
import '../../model/groupConversationModel.dart';
import '../../api/groupChatRecordAPI.dart';
import '../../api/getGroupInfoAPI.dart';
import '../../model/groupInfoModel.dart';
import '../../model/groupMemberModel.dart';
import '../../utils/chat_search_util.dart';
import '../../utils/WebSocketManager.dart';
import '../../shared/widgets/app_search_field.dart';
import '../../core/cache/app_image_cache.dart';
import '../../core/config/refresh_intervals.dart';
import '../../features/chat/domain/chat_realtime_event.dart';
import '../../features/chat/data/hidden_conversations_store.dart';
import '../../shared/widgets/swipe_action_cell.dart';

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

  Timer? _fallbackRefreshTimer;
  Timer? _refreshDebounceTimer;
  WebSocketMessageSubscription? _messageSubscription;
  GlobalUtil globalUtil = GlobalUtil();
  bool _isFetchingConversations = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final HiddenConversationsStore _hiddenConversationsStore =
      HiddenConversationsStore();
  Map<String, int> _hiddenConversations = {};
  String _hiddenConversationsOwner = '';
  // 头像 URL 缓存，用于避免重复加载
  Map<String, String> _avatarCache = {};

  @override
  void initState() {
    super.initState();
    // 延迟到构建完成后执行需要setState的操作
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _notifyUnreadCountChanged();
      await _ensureHiddenConversationsLoaded();
      fetchConversations();
      _startFallbackRefreshTimer();
    });

    _messageSubscription = WebSocketManager().addMessageListener(
      _handleWebSocketMessage,
    );

    // 注册未读消息数变化的回调
    globalUtil.onUnreadCountChanged = (userName, count) {
      // 确保在回调中不会在构建过程中触发setState
      if (mounted) {
        _updateChatUnreadCount(userName, count);
      }
    };
  }

  @override
  void dispose() {
    _fallbackRefreshTimer?.cancel();
    _refreshDebounceTimer?.cancel();
    _messageSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startFallbackRefreshTimer() {
    _fallbackRefreshTimer?.cancel();
    _fallbackRefreshTimer = Timer.periodic(
      RefreshIntervals.conversationFallback,
      (_) {
        if (mounted && !(globalUtil.isChatting ?? false)) {
          fetchConversations();
        }
      },
    );
  }

  void _handleWebSocketMessage(dynamic message) {
    if (message is! Map<String, dynamic>) {
      return;
    }

    final event = ChatRealtimeEvent.parse(message);
    switch (event.type) {
      case ChatRealtimeEventType.privateMessage:
        _storePrivateRealtimeMessage(event);
        break;
      case ChatRealtimeEventType.groupMessage:
        _storeGroupRealtimeMessage(event);
        break;
      case ChatRealtimeEventType.privateDelivery:
        final conversationId = globalUtil.conversationIdForMessage(
          event.messageId,
        );
        if (conversationId != null) {
          _unhideConversation('private:$conversationId');
        }
        globalUtil.updateOutgoingMessageStatus(
          event.messageId,
          event.deliveryStatus == 'failed'
              ? MessageStatus.failed
              : MessageStatus.sent,
        );
        break;
      case ChatRealtimeEventType.groupDelivery:
        final conversationId = globalUtil.conversationIdForMessage(
          event.clientMessageId,
        );
        if (conversationId != null) _unhideConversation(conversationId);
        globalUtil.reconcileOutgoingMessageId(
          event.clientMessageId,
          event.messageId,
        );
        globalUtil.updateOutgoingMessageStatus(
          event.messageId,
          event.code == 100 ? MessageStatus.sent : MessageStatus.failed,
        );
        break;
      case ChatRealtimeEventType.readReceipt:
      case ChatRealtimeEventType.other:
        break;
    }

    if (event.type == ChatRealtimeEventType.other) return;
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        fetchConversations();
      }
    });
  }

  void _storePrivateRealtimeMessage(ChatRealtimeEvent event) {
    if (event.senderId.isEmpty || event.messageId <= 0) return;
    _unhideConversation('private:${event.senderId}');
    final isOpenChat =
        globalUtil.isChatting == true &&
        globalUtil.currentChatUserName == event.senderId;
    if (isOpenChat) return;

    globalUtil.addMessage(
      event.senderId,
      Message(
        msgId: event.messageId,
        content: event.content,
        isMe: false,
        time: GlobalUtil.formatChatTimestamp(event.timestamp),
        isRead: false,
        conversationId: event.conversationId,
        messageType: event.messageType == 2
            ? MessageType.image
            : MessageType.text,
        status: MessageStatus.sent,
        senderId: event.senderId,
        timestamp: event.timestamp,
      ),
    );
    globalUtil.addUnreadMessage(event.senderId, event.messageId);
  }

  void _storeGroupRealtimeMessage(ChatRealtimeEvent event) {
    if (event.groupId <= 0 || event.senderId.isEmpty || event.messageId <= 0) {
      return;
    }
    final groupId = event.groupId.toString();
    final conversationKey = GlobalUtil.groupConversationKey(groupId);
    _unhideConversation(conversationKey);
    final isOpenChat =
        globalUtil.isChatting == true &&
        globalUtil.currentChatUserName == conversationKey;
    if (isOpenChat) return;

    globalUtil.addMessage(
      conversationKey,
      Message(
        msgId: event.messageId,
        content: event.content,
        isMe: false,
        time: GlobalUtil.formatChatTimestamp(event.timestamp),
        isRead: false,
        conversationId: groupId,
        messageType: event.messageType == 2
            ? MessageType.image
            : MessageType.text,
        status: MessageStatus.sent,
        senderId: event.senderId,
        timestamp: event.timestamp,
      ),
    );
    globalUtil.addUnreadMessage(conversationKey, event.messageId);
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

  String _hiddenKey(Chat chat) => chat.isGroup
      ? GlobalUtil.groupConversationKey(chat.userName)
      : 'private:${chat.userName}';

  Future<void> _ensureHiddenConversationsLoaded() async {
    final owner = globalUtil.userName ?? '';
    if (owner.isEmpty || owner == _hiddenConversationsOwner) return;
    _hiddenConversationsOwner = owner;
    _hiddenConversations = _hiddenConversationsStore.load(owner);
  }

  void _unhideConversation(String key) {
    if (_hiddenConversations.remove(key) == null) return;
    final owner = _hiddenConversationsOwner;
    if (owner.isNotEmpty) {
      unawaited(_hiddenConversationsStore.save(owner, _hiddenConversations));
    }
  }

  Future<void> _hideConversation(Chat chat) async {
    final owner = globalUtil.userName ?? '';
    if (owner.isEmpty) return;
    await _ensureHiddenConversationsLoaded();
    final key = _hiddenKey(chat);
    _hiddenConversations[key] = DateTime.now().millisecondsSinceEpoch;

    if (!mounted) return;
    setState(() {
      _chats.removeWhere(
        (item) =>
            item.userName == chat.userName && item.isGroup == chat.isGroup,
      );
      _notifyUnreadCountChanged();
    });
    final messageKey = chat.isGroup
        ? GlobalUtil.groupConversationKey(chat.userName)
        : chat.userName;
    globalUtil.clearUnreadMessages(messageKey);
    await _hiddenConversationsStore.save(owner, _hiddenConversations);
  }

  void _updateChatUnreadCount(String userName, int count) {
    setState(() {
      final index = _chats.indexWhere((element) {
        final key = element.isGroup
            ? GlobalUtil.groupConversationKey(element.userName)
            : element.userName;
        return key == userName;
      });
      if (index != -1) {
        // 更新未读消息数
        final updatedChat = Chat(
          name: _chats[index].name,
          avatar: _chats[index].avatar,
          lastMessage: _chats[index].lastMessage,
          time: _chats[index].time,
          unreadCount: count,
          userName: _chats[index].userName,
          isGroup: _chats[index].isGroup,
          lastSenderName: _chats[index].lastSenderName,
          updateTime: _chats[index].updateTime,
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
          updateTime: conversation.updateTime,
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
                // 优先使用已缓存的群成员，避免会话列表刷新时产生 N+1 请求。
                final groupMembers = globalUtil.getGroupMembers(
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
              updateTime: groupConversation.updateTime,
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

    return sortChatsByLatest(chatList);
  }

  Future<void> fetchConversations() async {
    if (_isFetchingConversations) {
      return;
    }
    _isFetchingConversations = true;
    try {
      final globalUtil = GlobalUtil();
      final currentUserName = globalUtil.userName;
      if (currentUserName == null) {
        debugPrint('当前用户未登录');
        return;
      }
      await _ensureHiddenConversationsLoaded();

      // 调用 API 获取单聊会话列表
      final conversations = await getConversationApi(currentUserName);
      // 调用 API 获取群聊会话列表
      final groupConversations = await getGroupConversations(currentUserName);

      // 转换为 Chat 列表并更新 UI
      final allChats = await _convertToChatList(
        conversations,
        groupConversations,
      );
      var hiddenChanged = false;
      final chatList = allChats.where((chat) {
        final key = _hiddenKey(chat);
        final hidden = _hiddenConversationsStore.shouldHide(
          _hiddenConversations,
          key,
          chat.updateTime,
        );
        if (!hidden && _hiddenConversations.remove(key) != null) {
          hiddenChanged = true;
        }
        return !hidden;
      }).toList();
      if (hiddenChanged) {
        await _hiddenConversationsStore.save(
          currentUserName,
          _hiddenConversations,
        );
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _chats.clear();
        _chats.addAll(chatList);
        _notifyUnreadCountChanged();
      });

      // 每次只比对服务端会话更新时间与本地最新消息。
      // 时间未变时只读本地，不再请求完整聊天记录。
      await _loadChatRecordsForConversations(conversations, currentUserName);
      await _loadGroupChatRecordsForConversations(
        groupConversations,
        currentUserName,
      );

      if (mounted && _searchQuery.isNotEmpty) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('获取会话列表失败：$e');
    } finally {
      _isFetchingConversations = false;
    }
  }

  List<_ChatSearchResult> _getSearchResults() {
    final keyword = _searchQuery.trim();
    if (keyword.isEmpty) {
      return const [];
    }

    final results = <_ChatSearchResult>[];
    for (final chat in _chats) {
      final conversationKey = chat.isGroup
          ? GlobalUtil.groupConversationKey(chat.userName)
          : chat.userName;
      final matches = globalUtil
          .getChatRecords(conversationKey)
          .where(
            (message) =>
                message.messageType == MessageType.text &&
                ChatSearchUtil.matches(message.content, keyword),
          )
          .toList();
      if (matches.isNotEmpty) {
        results.add(
          _ChatSearchResult(
            chat: chat,
            latestMatch: matches.last,
            matchCount: matches.length,
          ),
        );
      }
    }
    return results;
  }

  void _openChat(Chat chat) {
    if (chat.isGroup) {
      Navigator.pushNamed(
        context,
        '/groupChatDialog',
        arguments: {'groupId': chat.userName, 'groupName': chat.name},
      );
    } else {
      Navigator.pushNamed(context, '/chatDialog', arguments: chat.userName);
    }
  }

  Widget _buildHighlightedMessage(String content) {
    final preview = ChatSearchUtil.buildPreview(content, _searchQuery);
    return Text.rich(
      TextSpan(
        children: ChatSearchUtil.buildHighlightedSpans(
          content: preview,
          keyword: _searchQuery,
          normalStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          highlightedStyle: const TextStyle(
            color: Color(0xFF07C160),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSearchResults() {
    final results = _getSearchResults();
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 52, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('没有找到相关聊天记录', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 8),
      itemCount: results.length + 1,
      separatorBuilder: (_, index) => index == 0
          ? const SizedBox.shrink()
          : const Divider(height: 1, indent: 72, color: Color(0xFFE5E5E5)),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Text(
              '聊天记录（${results.length}）',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          );
        }

        final result = results[index - 1];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: CircleAvatar(
            backgroundImage: AppImageCache.provider(result.chat.avatar),
            backgroundColor: Colors.grey[200],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  result.chat.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                result.latestMatch.time,
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHighlightedMessage(result.latestMatch.content),
                if (result.matchCount > 1) ...[
                  const SizedBox(height: 3),
                  Text(
                    '共 ${result.matchCount} 条相关聊天记录',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          onTap: () => _openChat(result.chat),
        );
      },
    );
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

        try {
          await globalUtil.hydrateChatRecords(targetUserName);
          final cachedTimestamp = globalUtil.getLatestChatTimestamp(
            targetUserName,
          );
          if (cachedTimestamp < conversation.updateTime) {
            await globalUtil.loadChatRecords(targetUserName, 100);
          }

          debugPrint('已恢复$targetUserName的聊天记录');
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
        final conversationKey = GlobalUtil.groupConversationKey(groupIdStr);

        try {
          await globalUtil.hydrateChatRecords(conversationKey);
          if (globalUtil.getLatestChatTimestamp(conversationKey) >=
              groupConversation.updateTime) {
            continue;
          }

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
              time: GlobalUtil.formatChatTimestamp(model.sendTime),
              isRead: true,
              conversationId: groupIdStr,
              messageType: messageType,
              status: MessageStatus.sent, // 简化处理，使用默认值
              senderId: model.senderId,
              timestamp: model.sendTime,
            );
          }).toList();

          await globalUtil.mergeChatRecords(conversationKey, messages);

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
        titleSpacing: 12,
        title: AppSearchField(
          controller: _searchController,
          query: _searchQuery,
          hintText: '搜索聊天记录',
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
      body: _searchQuery.trim().isNotEmpty
          ? _buildSearchResults()
          : Padding(
              padding: EdgeInsets.only(top: 8),
              child: ListView.separated(
                itemCount: _chats.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 72,
                  color: Color(0xFFE5E5E5),
                ),
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return SwipeActionCell(
                    key: ValueKey('chat_${chat.isGroup}_${chat.userName}'),
                    onDelete: () => _hideConversation(chat),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: AppImageCache.provider(chat.avatar),
                        backgroundColor: Colors.grey[200],
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            chat.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ), // 确保文本颜色可见
                          ),
                          Text(
                            chat.time,
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: chat.isGroup
                                ? Text(
                                    chat.lastSenderName != null
                                        ? '${chat.lastSenderName}: ${chat.lastMessage}'
                                        : chat.lastMessage,
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : Text(
                                    chat.lastMessage,
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          if (chat.unreadCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                chat.unreadCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () => _openChat(chat),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _ChatSearchResult {
  final Chat chat;
  final Message latestMatch;
  final int matchCount;

  const _ChatSearchResult({
    required this.chat,
    required this.latestMatch,
    required this.matchCount,
  });
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
  final int updateTime;

  Chat({
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.userName,
    this.isGroup = false,
    this.lastSenderName,
    required this.updateTime,
  });
}

List<Chat> sortChatsByLatest(Iterable<Chat> chats) {
  final sortedChats = List<Chat>.of(chats);
  sortedChats.sort((a, b) => b.updateTime.compareTo(a.updateTime));
  return sortedChats;
}
