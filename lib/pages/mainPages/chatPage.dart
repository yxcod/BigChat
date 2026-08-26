import 'package:flutter/material.dart';
import 'dart:async';
import '../../model/conversationModel.dart';
import '../../api/getConversationAPI.dart';
import '../../utils/gloabl.dart';
import '../../model/friendInfoModel.dart';
import '../../model/messageModel.dart';
import '../../core/media/voice_message.dart';
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
import '../../features/chat/domain/chat_message_mapper.dart';
import '../../features/chat/domain/read_all_policy.dart';
import '../../features/chat/data/hidden_conversations_store.dart';
import '../../shared/widgets/swipe_action_cell.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';
import '../../utils/presence_event.dart';
import '../../features/groups/application/group_notification_settings_service.dart';

class Chatpage extends StatefulWidget {
  final List<Chat> chatList;
  final Function(int)? onUnreadCountChanged;
  final bool autoRefresh;

  const Chatpage({
    super.key,
    required this.chatList,
    this.onUnreadCountChanged,
    this.autoRefresh = true,
  });

  @override
  State<Chatpage> createState() => _ChatpageState();
}

class _ChatpageState extends State<Chatpage> {
  final List<Chat> _chats = [];

  Timer? _fallbackRefreshTimer;
  Timer? _refreshDebounceTimer;
  WebSocketMessageSubscription? _messageSubscription;
  GlobalUtil globalUtil = GlobalUtil();
  bool _isFetchingConversations = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _conversationScrollController = ScrollController();
  String _searchQuery = '';
  final HiddenConversationsStore _hiddenConversationsStore =
      HiddenConversationsStore();
  Map<String, int> _hiddenConversations = {};
  String _hiddenConversationsOwner = '';
  final Set<int> _locallyReadGroupIds = {};
  final GroupNotificationSettingsService _groupNotificationSettings =
      GroupNotificationSettingsService.instance;
  bool _isMarkingAllRead = false;
  // 头像 URL 缓存，用于避免重复加载
  final Map<String, String> _avatarCache = {};

  @override
  void initState() {
    super.initState();
    globalUtil.privacyMessagesRevision.addListener(_refreshPrivacyMessages);
    _groupNotificationSettings.addListener(
      _handleGroupNotificationSettingsChanged,
    );
    _chats.addAll(
      sortChatsByLatest(widget.chatList.map(_applyGroupNotificationSetting)),
    );
    if (!widget.autoRefresh) return;
    // 延迟到构建完成后执行需要setState的操作
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _notifyUnreadCountChanged();
      await _groupNotificationSettings.ensureCurrentUserLoaded();
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

  void _refreshPrivacyMessages() {
    if (!mounted) return;
    // 销毁隐私消息后重新以服务端会话摘要为底，再叠加仍存活的内存消息，
    // 避免会话列表继续显示已经销毁的隐私内容。
    if (widget.autoRefresh) {
      unawaited(fetchConversations());
    } else {
      setState(() {});
    }
  }

  Message? _latestPrivacyMessage(String conversationKey) {
    Message? latest;
    for (final message in globalUtil.getChatRecords(conversationKey)) {
      if (!message.isPrivacy) continue;
      if (latest == null ||
          message.timestamp > latest.timestamp ||
          (message.timestamp == latest.timestamp &&
              message.msgId > latest.msgId)) {
        latest = message;
      }
    }
    return latest;
  }

  String _conversationTime(int timestamp) {
    final formatted = GlobalUtil.formatTimestamp(timestamp);
    return formatted.length >= 16 ? formatted.substring(11, 16) : formatted;
  }

  String _privacySenderLabel(Chat chat, Message message) {
    final senderId = message.senderId?.trim() ?? '';
    if (senderId.isEmpty) return chat.lastSenderName ?? '';
    if (senderId == globalUtil.userName) return '我';
    if (chat.isGroup) {
      final groupId = int.tryParse(chat.userName) ?? 0;
      for (final member in globalUtil.getGroupMembers(groupId)) {
        if (member.userId == senderId &&
            member.groupNickName.trim().isNotEmpty) {
          return member.groupNickName.trim();
        }
      }
    }
    final friend = globalUtil.getFriendInfoByUserName(senderId);
    final remark = friend.remarks?.trim() ?? '';
    if (remark.isNotEmpty) return remark;
    final nickname = friend.nickName?.trim() ?? '';
    return nickname.isNotEmpty ? nickname : senderId;
  }

  Chat _applyPrivacyConversationPreview(Chat chat) {
    final conversationKey = chat.isGroup
        ? GlobalUtil.groupConversationKey(chat.userName)
        : chat.userName;
    final message = _latestPrivacyMessage(conversationKey);
    if (message == null || message.timestamp < chat.updateTime) return chat;
    return chat.copyWith(
      lastMessage: messageQuotePreview(message),
      time: _conversationTime(message.timestamp),
      updateTime: message.timestamp,
      lastSenderName: chat.isGroup
          ? _privacySenderLabel(chat, message)
          : chat.lastSenderName,
    );
  }

  void _showRealtimePrivacyPreview(String conversationKey) {
    final index = _chats.indexWhere((chat) {
      final key = chat.isGroup
          ? GlobalUtil.groupConversationKey(chat.userName)
          : chat.userName;
      return key == conversationKey;
    });
    if (index < 0 || !mounted) return;
    setState(() {
      _chats[index] = _applyPrivacyConversationPreview(_chats[index]);
      _chats.sort((left, right) => right.updateTime.compareTo(left.updateTime));
    });
  }

  Chat _applyGroupNotificationSetting(Chat chat) {
    if (!chat.isGroup) return chat;
    final groupId = int.tryParse(chat.userName) ?? 0;
    final muted = _groupNotificationSettings.isMuted(groupId);
    final rawUnreadCount = chat.rawUnreadCount;
    return chat.copyWith(
      isMuted: muted,
      unreadCount: muted ? 0 : rawUnreadCount,
      hasMutedUnread: muted && rawUnreadCount > 0,
    );
  }

  void _handleGroupNotificationSettingsChanged() {
    if (!mounted) return;
    setState(() {
      for (var index = 0; index < _chats.length; index++) {
        _chats[index] = _applyGroupNotificationSetting(_chats[index]);
      }
      _notifyUnreadCountChanged();
    });
    if (widget.autoRefresh) unawaited(fetchConversations());
  }

  @override
  void dispose() {
    globalUtil.privacyMessagesRevision.removeListener(_refreshPrivacyMessages);
    _groupNotificationSettings.removeListener(
      _handleGroupNotificationSettingsChanged,
    );
    _fallbackRefreshTimer?.cancel();
    _refreshDebounceTimer?.cancel();
    _messageSubscription?.cancel();
    _searchController.dispose();
    _conversationScrollController.dispose();
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
    if (message['type'] == 'privacyMessageDestroy') {
      final rawId = message['msgId'];
      final msgId = rawId is num
          ? rawId.toInt()
          : int.tryParse(rawId?.toString() ?? '');
      if (msgId != null) globalUtil.destroyPrivacyMessage(msgId);
      if (mounted) setState(() {});
      return;
    }
    final presence = PresenceEvent.tryParse(message);
    if (presence != null) {
      _updatePresence(presence.userName, presence.isOnline);
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
      case ChatRealtimeEventType.groupReadReceipt:
        if (event.code == 100 &&
            event.readerId == globalUtil.userName &&
            event.groupId > 0) {
          _locallyReadGroupIds.add(event.groupId);
          globalUtil.clearUnreadMessages(
            GlobalUtil.groupConversationKey(event.groupId),
          );
        }
        break;
      case ChatRealtimeEventType.groupHistoryDeleted:
        unawaited(_handleGroupHistoryDeleted(message));
        break;
      case ChatRealtimeEventType.groupMemberRemoved:
        unawaited(_handleRemovedGroup(event.groupId));
        break;
      case ChatRealtimeEventType.groupMemberRoleUpdated:
        break;
      case ChatRealtimeEventType.readReceipt:
      case ChatRealtimeEventType.other:
        break;
    }

    if (event.type == ChatRealtimeEventType.other ||
        event.type == ChatRealtimeEventType.groupHistoryDeleted ||
        event.type == ChatRealtimeEventType.groupMemberRemoved) {
      return;
    }
    _refreshDebounceTimer?.cancel();
    _refreshDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        fetchConversations();
      }
    });
  }

  void _updatePresence(String userName, bool isOnline) {
    if (!mounted) return;
    final index = _chats.indexWhere(
      (chat) => !chat.isGroup && chat.userName == userName,
    );
    if (index == -1 || _chats[index].isOnline == isOnline) return;
    setState(() {
      _chats[index] = _chats[index].copyWith(isOnline: isOnline);
    });
  }

  Future<void> _handleGroupHistoryDeleted(Map<String, dynamic> message) async {
    final groupId = int.tryParse(message['groupId']?.toString() ?? '') ?? 0;
    if (groupId <= 0) return;
    final conversationKey = GlobalUtil.groupConversationKey(groupId);
    final isOpenChat =
        globalUtil.isChatting == true &&
        globalUtil.currentChatUserName == conversationKey;

    await globalUtil.deleteChatRecords(conversationKey);
    _locallyReadGroupIds.remove(groupId);
    if (!mounted) return;
    setState(() {
      _chats.removeWhere(
        (chat) => chat.isGroup && chat.userName == groupId.toString(),
      );
      _notifyUnreadCountChanged();
    });
    if (!isOpenChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message['message']?.toString() ?? '群主或管理员已删除当前群聊的全部聊天记录',
          ),
        ),
      );
    }
  }

  Future<void> _handleRemovedGroup(int groupId) async {
    if (groupId <= 0) return;
    final conversationKey = GlobalUtil.groupConversationKey(groupId);
    await globalUtil.deleteChatRecords(conversationKey);
    _locallyReadGroupIds.remove(groupId);
    if (!mounted) return;
    setState(() {
      _chats.removeWhere(
        (chat) => chat.isGroup && chat.userName == groupId.toString(),
      );
      _notifyUnreadCountChanged();
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
        messageType: switch (event.messageType) {
          2 => MessageType.image,
          3 => MessageType.audio,
          4 => MessageType.video,
          5 => MessageType.file,
          _ => MessageType.text,
        },
        status: MessageStatus.sent,
        senderId: event.senderId,
        timestamp: event.timestamp,
        isPrivacy: event.data['privacyMode'] == true,
        privacyReadDelaySeconds:
            int.tryParse(
              event.data['privacyReadDelaySeconds']?.toString() ?? '',
            ) ??
            10,
        privacyUnreadDelaySeconds:
            int.tryParse(
              event.data['privacyUnreadDelaySeconds']?.toString() ?? '',
            ) ??
            180,
      ),
    );
    if (event.data['privacyMode'] == true) {
      _showRealtimePrivacyPreview(event.senderId);
    }
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
    _locallyReadGroupIds.remove(event.groupId);

    globalUtil.addMessage(
      conversationKey,
      Message(
        msgId: event.messageId,
        content: event.content,
        isMe: false,
        time: GlobalUtil.formatChatTimestamp(event.timestamp),
        isRead: false,
        conversationId: groupId,
        messageType: switch (event.messageType) {
          2 => MessageType.image,
          3 => MessageType.audio,
          4 => MessageType.video,
          5 => MessageType.file,
          _ => MessageType.text,
        },
        status: MessageStatus.sent,
        senderId: event.senderId,
        timestamp: event.timestamp,
        isPrivacy: event.data['privacyMode'] == true,
        privacyReadDelaySeconds:
            int.tryParse(
              event.data['privacyReadDelaySeconds']?.toString() ?? '',
            ) ??
            10,
        privacyUnreadDelaySeconds:
            int.tryParse(
              event.data['privacyUnreadDelaySeconds']?.toString() ?? '',
            ) ??
            180,
      ),
    );
    if (event.data['privacyMode'] == true) {
      _showRealtimePrivacyPreview(conversationKey);
    }
    final muted = _groupNotificationSettings.isMuted(event.groupId);
    if (muted) {
      final index = _chats.indexWhere(
        (chat) => chat.isGroup && chat.userName == groupId,
      );
      if (index >= 0 && mounted) {
        setState(() {
          final chat = _chats[index];
          _chats[index] = chat.copyWith(
            isMuted: true,
            unreadCount: 0,
            rawUnreadCount: chat.rawUnreadCount + 1,
            hasMutedUnread: true,
          );
          _notifyUnreadCountChanged();
        });
      }
    } else {
      globalUtil.addUnreadMessage(conversationKey, event.messageId);
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
        final chat = _chats[index];
        _chats[index] = chat.copyWith(
          unreadCount: chat.isMuted ? 0 : count,
          rawUnreadCount: count,
          hasMutedUnread: chat.isMuted && count > 0,
        );
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
          lastMessage: chatVoicePreview(conversation.lastMsg ?? ''),
          time: formattedTime.substring(11, 16), // 只显示时分
          unreadCount: conversation.unreadCount,
          userName: targetUserName,
          isGroup: false,
          isOnline: friend.isOnline ?? false,
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
          final serverUnreadCount = groupConversation.unreadCount;
          final locallyRead = _locallyReadGroupIds.contains(
            groupConversation.groupId,
          );
          if (serverUnreadCount == 0) {
            _locallyReadGroupIds.remove(groupConversation.groupId);
          }
          final rawUnreadCount = locallyRead ? 0 : serverUnreadCount;
          final muted = _groupNotificationSettings.isMuted(
            groupConversation.groupId,
          );
          chatList.add(
            Chat(
              name: groupInfo.groupName,
              avatar: avatarURL,
              lastMessage: chatVoicePreview(groupConversation.lastMsg),
              time: formattedTime.substring(11, 16), // 只显示时分
              unreadCount: muted ? 0 : rawUnreadCount,
              rawUnreadCount: rawUnreadCount,
              userName: groupIdStr,
              isGroup: true,
              isMuted: muted,
              hasMutedUnread: muted && rawUnreadCount > 0,
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

    return sortChatsByLatest(chatList.map(_applyPrivacyConversationPreview));
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

  Future<void> _openChat(Chat chat) async {
    if (chat.isGroup) {
      final groupId = int.tryParse(chat.userName);
      if (groupId != null) _locallyReadGroupIds.add(groupId);
      final conversationKey = GlobalUtil.groupConversationKey(chat.userName);
      globalUtil.clearUnreadMessages(conversationKey);
      await Navigator.pushNamed(
        context,
        '/groupChatDialog',
        arguments: {'groupId': chat.userName, 'groupName': chat.name},
      );
      if (!mounted) return;
      globalUtil.clearUnreadMessages(conversationKey);
      await fetchConversations();
    } else {
      await Navigator.pushNamed(
        context,
        '/chatDialog',
        arguments: chat.userName,
      );
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
          final normalizedMessages =
              globalUtil
                  .getChatRecords(conversationKey)
                  .map(
                    (message) => ChatMessageMapper.rebindOwnership(
                      message,
                      currentUserId: currentUserName,
                    ),
                  )
                  .toList()
                ..sort((left, right) {
                  final byTime = left.timestamp.compareTo(right.timestamp);
                  return byTime != 0
                      ? byTime
                      : left.msgId.compareTo(right.msgId);
                });
          if (normalizedMessages.isNotEmpty) {
            await globalUtil.replaceChatRecords(
              conversationKey,
              normalizedMessages,
            );
          }
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
              case 3:
                messageType = MessageType.audio;
                break;
              case 4:
                messageType = MessageType.video;
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

  Future<void> _markAllUnreadAsRead() async {
    if (_isMarkingAllRead) return;
    final webSocket = WebSocketManager();
    if (!webSocket.isConnected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('服务器未连接，暂时无法标记已读')));
      return;
    }

    final currentUserId = globalUtil.userName?.trim() ?? '';
    if (currentUserId.isEmpty) return;

    final targets = _chats
        .where((chat) {
          final conversationKey = chat.isGroup
              ? GlobalUtil.groupConversationKey(chat.userName)
              : chat.userName;
          return chat.rawUnreadCount > 0 ||
              globalUtil.getUnreadMessages(conversationKey).isNotEmpty;
        })
        .toList(growable: false);
    if (targets.isEmpty) return;

    setState(() => _isMarkingAllRead = true);
    final readConversationKeys = <String>{};
    var failedConversationCount = 0;

    for (final chat in targets) {
      final conversationKey = chat.isGroup
          ? GlobalUtil.groupConversationKey(chat.userName)
          : chat.userName;
      final pending = pendingReadAcks(
        messages: globalUtil.getChatRecords(conversationKey),
        unreadMessageIds: globalUtil.getUnreadMessages(conversationKey),
        fallbackSenderId: chat.isGroup ? '' : chat.userName,
      );

      var queued = pending.isNotEmpty;
      if (chat.isGroup) {
        final groupId = int.tryParse(chat.userName) ?? 0;
        if (groupId <= 0) {
          queued = false;
        } else {
          for (final ack in pending.where((item) => item.isPrivacy)) {
            queued =
                webSocket.send({
                  'type': 'groupChatCallback',
                  'msgId': ack.messageId,
                  'receiveId': ack.senderId,
                  'sender': currentUserId,
                  'groupId': groupId,
                  'sessionId': groupId,
                  'status': 'read',
                  'privacyMode': true,
                }) &&
                queued;
          }

          final normalMessageIds = pending
              .where((item) => !item.isPrivacy)
              .map((item) => item.messageId);
          if (normalMessageIds.isNotEmpty) {
            final readThroughMsgId = normalMessageIds.reduce(
              (current, next) => next > current ? next : current,
            );
            queued =
                webSocket.send({
                  'type': 'groupChatRead',
                  'reader': currentUserId,
                  'groupId': groupId,
                  'sessionId': groupId,
                  'readThroughMsgId': readThroughMsgId,
                }) &&
                queued;
          }
        }
      } else {
        final sessionId = GlobalUtil.generateSessionId(
          currentUserId,
          chat.userName,
        );
        for (final ack in pending) {
          queued =
              webSocket.send({
                'type': 'chatCallback',
                'msgId': ack.messageId,
                'receiveId': ack.senderId,
                'sender': currentUserId,
                'sessionId': sessionId,
                if (ack.isPrivacy) 'privacyMode': true,
              }) &&
              queued;
        }
      }

      if (!queued) {
        failedConversationCount++;
        continue;
      }
      if (chat.isGroup) {
        _locallyReadGroupIds.add(int.parse(chat.userName));
      }
      globalUtil.markAllMessagesAsRead(conversationKey);
      globalUtil.clearUnreadMessages(conversationKey);
      readConversationKeys.add(conversationKey);
    }

    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _chats.length; i++) {
        final chat = _chats[i];
        final conversationKey = chat.isGroup
            ? GlobalUtil.groupConversationKey(chat.userName)
            : chat.userName;
        if (readConversationKeys.contains(conversationKey)) {
          _chats[i] = chat.copyWith(
            unreadCount: 0,
            rawUnreadCount: 0,
            hasMutedUnread: false,
          );
        }
      }
      _isMarkingAllRead = false;
      _notifyUnreadCountChanged();
    });

    if (failedConversationCount > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('部分消息尚未加载，请稍后再试')));
    }
  }

  Widget _buildUnreadSummary() {
    final total = _calculateTotalUnreadCount();
    if (total <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Material(
        key: const ValueKey('chat_unread_summary'),
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isMarkingAllRead
              ? null
              : () => unawaited(_markAllUnreadAsRead()),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border.all(color: context.appDivider),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF8F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cleaning_services_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    '已收到 $total 条新消息',
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _isMarkingAllRead ? '处理中' : '一键已读',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationAvatar(Chat chat) {
    final hasAvatar = chat.avatar.trim().isNotEmpty;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFEAF8F0),
            backgroundImage: hasAvatar
                ? AppImageCache.provider(chat.avatar)
                : null,
            child: hasAvatar
                ? null
                : Icon(
                    chat.isGroup
                        ? Icons.groups_2_outlined
                        : Icons.person_outline_rounded,
                    color: AppColors.primary,
                    size: 25,
                  ),
          ),
          if (!chat.isGroup && chat.isOnline)
            Positioned(
              right: -1,
              bottom: 1,
              child: Container(
                key: ValueKey('chat_online_${chat.userName}'),
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.appSurface, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _conversationPreview(Chat chat) {
    if (chat.isGroup && chat.lastSenderName?.isNotEmpty == true) {
      return '${chat.lastSenderName}：${chat.lastMessage}';
    }
    return chat.lastMessage;
  }

  Widget _buildUnreadBadge(Chat chat) {
    final label = chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString();
    return Container(
      key: ValueKey('chat_unread_badge_${chat.userName}'),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          height: 1.15,
        ),
      ),
    );
  }

  Widget _buildMutedUnreadDot(Chat chat) {
    return Container(
      key: ValueKey('chat_muted_unread_dot_${chat.userName}'),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFFB8BBC2),
        shape: BoxShape.circle,
        border: Border.all(color: context.appSurface, width: 1.5),
      ),
    );
  }

  Widget _buildConversationTile(Chat chat) {
    return SwipeActionCell(
      key: ValueKey('chat_${chat.isGroup}_${chat.userName}'),
      onDelete: () => _hideConversation(chat),
      child: InkWell(
        onTap: () => _openChat(chat),
        child: SizedBox(
          height: 78,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                _buildConversationAvatar(chat),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            chat.time,
                            style: const TextStyle(
                              color: Color(0xFFA4A7AC),
                              fontSize: 11,
                            ),
                          ),
                          if (chat.isGroup && chat.isMuted) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.notifications_off_outlined,
                              color: Color(0xFFB5B8BE),
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _conversationPreview(chat),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (chat.hasMutedUnread) ...[
                            const SizedBox(width: 10),
                            _buildMutedUnreadDot(chat),
                          ] else if (chat.unreadCount > 0) ...[
                            const SizedBox(width: 10),
                            _buildUnreadBadge(chat),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationList() {
    if (_chats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 46,
              color: Color(0xFFC6C8CC),
            ),
            SizedBox(height: 12),
            Text(
              '暂无聊天会话',
              style: TextStyle(color: context.appTextSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: fetchConversations,
      child: ListView.separated(
        key: const ValueKey('chat_conversation_list'),
        controller: _conversationScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _chats.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          thickness: 0.6,
          indent: 81,
          endIndent: 16,
          color: context.appDivider,
        ),
        itemBuilder: (context, index) => _buildConversationTile(_chats[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 56,
        centerTitle: true,
        title: Text(
          '聊天',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              key: const ValueKey('chat_create_group_button'),
              tooltip: '创建群聊',
              onPressed: () => Navigator.pushNamed(context, '/groupCreatePage'),
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF34373C)),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: context.appTextPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: context.appSurface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: AppSearchField(
              controller: _searchController,
              query: _searchQuery,
              hintText: '搜索聊天记录',
              onChanged: (value) => setState(() => _searchQuery = value),
              height: 44,
            ),
          ),
          if (_searchQuery.trim().isEmpty) _buildUnreadSummary(),
          Expanded(
            child: Container(
              key: const ValueKey('chat_list_surface'),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _searchQuery.trim().isNotEmpty
                  ? _buildSearchResults()
                  : _buildConversationList(),
            ),
          ),
        ],
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
  final int rawUnreadCount;
  final String userName;
  final bool isGroup; // 是否为群聊
  final bool isOnline;
  final String? lastSenderName; // 群聊最后一条消息的发送者名称
  final int updateTime;
  final bool isMuted;
  final bool hasMutedUnread;

  Chat({
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    int? rawUnreadCount,
    required this.userName,
    this.isGroup = false,
    this.isOnline = false,
    this.lastSenderName,
    required this.updateTime,
    this.isMuted = false,
    this.hasMutedUnread = false,
  }) : rawUnreadCount = rawUnreadCount ?? unreadCount;

  Chat copyWith({
    String? lastMessage,
    String? time,
    int? unreadCount,
    int? rawUnreadCount,
    bool? isOnline,
    String? lastSenderName,
    int? updateTime,
    bool? isMuted,
    bool? hasMutedUnread,
  }) {
    return Chat(
      name: name,
      avatar: avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      time: time ?? this.time,
      unreadCount: unreadCount ?? this.unreadCount,
      rawUnreadCount: rawUnreadCount ?? this.rawUnreadCount,
      userName: userName,
      isGroup: isGroup,
      isOnline: isOnline ?? this.isOnline,
      lastSenderName: lastSenderName ?? this.lastSenderName,
      updateTime: updateTime ?? this.updateTime,
      isMuted: isMuted ?? this.isMuted,
      hasMutedUnread: hasMutedUnread ?? this.hasMutedUnread,
    );
  }
}

List<Chat> sortChatsByLatest(Iterable<Chat> chats) {
  final sortedChats = List<Chat>.of(chats);
  sortedChats.sort((a, b) => b.updateTime.compareTo(a.updateTime));
  return sortedChats;
}
