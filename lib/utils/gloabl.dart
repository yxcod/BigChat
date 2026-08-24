import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/storageUtil.dart';
import '../model/userInfoModel.dart';
import '../model/friendInfoModel.dart';
import '../model/messageModel.dart';
import '../model/groupMemberModel.dart';
import '../utils/http.dart';
import '../api/getChatMessagesAPI.dart';
import '../core/config/app_config.dart';
import '../features/chat/application/chat_store.dart';
import '../features/chat/domain/chat_message_mapper.dart';
import '../features/chat/domain/chat_time_formatter.dart';
import '../features/chat/data/chat_local_cache.dart';
import '../features/chat/data/hidden_messages_store.dart';
import '../features/groups/application/group_member_cache.dart';

class GlobalUtil {
  String? _token;
  String? _userName;
  bool? _isLoading;
  UserInfoModel? _userInfoModel;
  bool? _isChatting;
  String? _currentChatUserName;
  Function(String, int)? onUnreadCountChanged;

  final ChatStore _chatStore = ChatStore();
  final ChatLocalCache _chatLocalCache = ChatLocalCache();
  final HiddenMessagesStore _hiddenMessagesStore = HiddenMessagesStore();
  final GroupMemberCache _groupMemberCache = GroupMemberCache();
  final Map<String, Timer> _chatCacheWriteTimers = {};

  static final GlobalUtil _instance = GlobalUtil._internal();
  factory GlobalUtil() {
    return _instance;
  }
  GlobalUtil._internal();

  static String groupConversationKey(Object groupId) => 'group:$groupId';

  UserInfoModel get userInfoModel =>
      _userInfoModel ?? UserInfoModel.formJSON({});
  String get baseURL => AppConfig.apiBaseUrl;
  String get baseWebSocketURL => AppConfig.webSocketBaseUrl;
  String? get token => _token ?? StorageUtil.getString('global_token');
  String? get userName => _userName ?? StorageUtil.getString('global_userName');
  bool? get isLoading => _isLoading ?? StorageUtil.getBool('global_isLoading');
  bool? get isChatting => _isChatting ?? false;
  String? get currentChatUserName => _currentChatUserName;

  set token(String? value) {
    _token = value;
    if (value != null) {
      StorageUtil.setString('global_token', value);
    }
  }

  set userName(String? value) {
    final previousValue = _userName ?? StorageUtil.getString('global_userName');
    if (previousValue != null &&
        previousValue.isNotEmpty &&
        value != null &&
        value.isNotEmpty &&
        previousValue != value) {
      resetSessionState();
    }
    _userName = value;
    if (value != null) {
      StorageUtil.setString('global_userName', value);
    }
  }

  void resetSessionState() {
    for (final timer in _chatCacheWriteTimers.values) {
      timer.cancel();
    }
    _chatCacheWriteTimers.clear();
    _chatStore.clearAllMessages();
    _chatStore.clearAllUnreadMessages();
    _groupMemberCache.clear();
    _userInfoModel = null;
    _isChatting = false;
    _currentChatUserName = null;
    onUnreadCountChanged = null;
    _userName = null;
    _token = null;
  }

  set isLoading(bool? value) {
    _isLoading = value;
    if (value != null) {
      StorageUtil.setBool('global_isLoading', value);
    }
  }

  set isChatting(bool? value) {
    _isChatting = value;
  }

  set currentChatUserName(String? value) {
    _currentChatUserName = value;
  }

  set userInfoModel(UserInfoModel? value) {
    _userInfoModel = value;
  }

  // 管理未读消息的方法

  // 添加一条未读消息
  void addUnreadMessage(String userName, int msgId) {
    final count = _chatStore.addUnreadMessage(userName, msgId);

    // 通知未读消息数变化，使用addPostFrameCallback确保不在构建过程中调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onUnreadCountChanged?.call(userName, count);
    });
  }

  // 获取某个用户的所有未读消息ID
  List<int> getUnreadMessages(String userName) {
    return _chatStore.unreadMessageIds(userName);
  }

  // 清除某个用户的所有未读消息
  void clearUnreadMessages(String userName) {
    _chatStore.clearUnreadMessages(userName);

    // 通知未读消息数变化，使用addPostFrameCallback确保不在构建过程中调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onUnreadCountChanged?.call(userName, 0);
    });
  }

  // 获取某个用户的未读消息数
  int getUnreadCount(String userName) {
    return _chatStore.unreadCount(userName);
  }

  // 聊天记录管理方法

  // 添加消息到聊天记录
  void addMessage(String userName, Message message) {
    if (_isMessageHidden(userName, message.msgId)) return;
    if (_chatStore.addMessage(userName, message)) {
      _scheduleChatCacheWrite(userName);
    }
  }

  // 获取某个用户的所有聊天记录
  List<Message> getChatRecords(String userName) {
    return _chatStore.messages(userName);
  }

  // 获取聊天记录的当前加载数量
  int getChatRecordsCount(String userName) {
    return _chatStore.messageCount(userName);
  }

  String? conversationIdForMessage(int messageId) {
    return _chatStore.conversationIdForMessage(messageId);
  }

  Future<bool> hydrateChatRecords(String conversationId) async {
    if (_chatStore.messageCount(conversationId) > 0) return true;
    final ownerId = userName ?? '';
    if (ownerId.isEmpty) return false;

    var messages = _filterHiddenMessages(
      conversationId,
      await _chatLocalCache.load(ownerId, conversationId),
    );
    if (messages.isEmpty && conversationId.startsWith('group:')) {
      final legacyId = conversationId.substring('group:'.length);
      messages = _filterHiddenMessages(
        conversationId,
        await _chatLocalCache.load(ownerId, legacyId),
      );
      if (messages.isNotEmpty) {
        _chatStore.replaceMessages(conversationId, messages);
        await persistChatRecords(conversationId);
        return true;
      }
    }
    if (messages.isEmpty) return false;
    _chatStore.replaceMessages(conversationId, messages);
    return true;
  }

  int getLatestChatTimestamp(String conversationId) {
    return _chatStore
        .messages(conversationId)
        .fold<int>(
          0,
          (latest, message) =>
              message.timestamp > latest ? message.timestamp : latest,
        );
  }

  void _scheduleChatCacheWrite(String conversationId) {
    _chatCacheWriteTimers[conversationId]?.cancel();
    _chatCacheWriteTimers[conversationId] = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(persistChatRecords(conversationId)),
    );
  }

  Future<void> persistChatRecords(String conversationId) async {
    final ownerId = userName ?? '';
    if (ownerId.isEmpty) return;
    await _chatLocalCache.save(
      ownerId,
      conversationId,
      _chatStore.messageSnapshot(conversationId),
    );
  }

  Future<void> replaceChatRecords(
    String conversationId,
    List<Message> messages,
  ) async {
    final localQuotes = <int, MessageQuote>{
      for (final message in _chatStore.messages(conversationId))
        if (message.quote != null) message.msgId: message.quote!,
    };
    final visibleMessages = _filterHiddenMessages(conversationId, messages).map(
      (message) {
        final localQuote = localQuotes[message.msgId];
        return message.quote == null && localQuote != null
            ? message.withQuote(localQuote)
            : message;
      },
    ).toList();
    _chatStore.replaceMessages(conversationId, visibleMessages);
    await persistChatRecords(conversationId);
  }

  Future<void> mergeChatRecords(
    String conversationId,
    List<Message> messages,
  ) async {
    _chatStore.mergeMessages(
      conversationId,
      _filterHiddenMessages(conversationId, messages),
    );
    await persistChatRecords(conversationId);
  }

  void updateOutgoingMessageStatus(int messageId, MessageStatus status) {
    final conversationId = _chatStore.updateMessageStatus(messageId, status);
    if (conversationId != null) _scheduleChatCacheWrite(conversationId);
  }

  void reconcileOutgoingMessageId(int clientMessageId, int serverMessageId) {
    if (clientMessageId <= 0 || serverMessageId <= 0) return;
    final conversationId = _chatStore.reconcileMessageId(
      clientMessageId,
      serverMessageId,
    );
    if (conversationId != null) _scheduleChatCacheWrite(conversationId);
  }

  Future<void> flushChatRecordsToLocal() async {
    for (final timer in _chatCacheWriteTimers.values) {
      timer.cancel();
    }
    _chatCacheWriteTimers.clear();
    await Future.wait(_chatStore.conversationIds.map(persistChatRecords));
  }

  // 加载指定数量的聊天记录
  Future<void> loadChatRecords(String userName, int count) async {
    try {
      // 获取当前用户的userName
      final currentUserName = this.userName ?? '';
      if (currentUserName.isEmpty) {
        throw Exception('当前用户未登录');
      }

      // 生成会话ID
      final sessionId = generateSessionId(currentUserName, userName);

      // 调用API获取聊天记录
      final messageModels = await getChatMessagesApi(
        conversationId: sessionId,
        userName: currentUserName,
        count: count,
      );

      // 检查是否有新记录：只有当获取到的记录数量小于1时，才认为没有更多记录了
      // 这样修改是因为后端可能返回少于请求数量的记录（例如当接近记录末尾时）
      if (messageModels.isEmpty) {
        debugPrint('没有获取到新的聊天记录');
        return; // 直接返回，不更新_chatRecords
      }

      // 如果之前已经有记录，并且获取到的记录数量与之前相同，
      // 我们仍然应该更新记录，因为可能有新的记录内容
      final currentCount = getChatRecordsCount(userName);
      if (currentCount > 0 && messageModels.length == currentCount) {
        debugPrint('获取到的记录数量与之前相同，但仍将更新记录');
      }

      // 转换为Message对象
      final messages = messageModels
          .map(
            (model) => ChatMessageMapper.fromPrivateRecord(
              model,
              currentUserId: currentUserName,
            ),
          )
          .toList();

      // 保存到_chatRecords
      await mergeChatRecords(userName, messages);

      debugPrint('成功加载$count条聊天记录');
    } catch (e) {
      debugPrint('加载聊天记录失败: $e');
      rethrow;
    }
  }

  // 加载更多聊天记录
  Future<void> loadMoreChatRecords(String userName) async {
    try {
      // 当前已加载的记录数
      final currentCount = getChatRecordsCount(userName);

      // 计算需要加载的记录数（每次增加100条）
      final nextCount = currentCount + 100;

      // 调用API获取更多聊天记录
      await loadChatRecords(userName, nextCount);
    } catch (e) {
      debugPrint('加载更多聊天记录失败: $e');
      rethrow;
    }
  }

  // 清除某个用户的所有聊天记录
  void clearChatRecords(String userName) {
    _chatStore.clearMessages(userName);
  }

  // 删除内存及磁盘中的指定会话记录，防止下次启动从本地缓存恢复。
  Future<void> deleteChatRecords(String conversationId) async {
    _chatCacheWriteTimers.remove(conversationId)?.cancel();
    _chatStore.clearMessages(conversationId);
    _chatStore.clearUnreadMessages(conversationId);

    final ownerId = userName ?? '';
    if (ownerId.isNotEmpty) {
      await _chatLocalCache.delete(ownerId, conversationId);
      if (conversationId.startsWith('group:')) {
        final legacyId = conversationId.substring('group:'.length);
        await _chatLocalCache.delete(ownerId, legacyId);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onUnreadCountChanged?.call(conversationId, 0);
    });
  }

  // 清除所有聊天记录
  void clearAllChatRecords() {
    _chatStore.clearAllMessages();
  }

  // 标记特定消息为已读
  void markMessageAsRead(String userName, int msgId) {
    _chatStore.markMessageAsRead(userName, msgId);
    _scheduleChatCacheWrite(userName);
  }

  // 标记所有消息为已读
  void markAllMessagesAsRead(String userName) {
    _chatStore.markAllIncomingMessagesAsRead(userName);
    _scheduleChatCacheWrite(userName);
  }

  // 删除指定消息
  void deleteMessage(String userName, int msgId) {
    final ownerId = this.userName ?? '';
    if (ownerId.isNotEmpty) {
      unawaited(_hiddenMessagesStore.hide(ownerId, userName, msgId));
    }
    _chatStore.deleteMessage(userName, msgId);
    _scheduleChatCacheWrite(userName);
  }

  bool _isMessageHidden(String conversationId, int messageId) {
    final ownerId = userName ?? '';
    if (ownerId.isEmpty) return false;
    return _hiddenMessagesStore.isHidden(ownerId, conversationId, messageId);
  }

  List<Message> _filterHiddenMessages(
    String conversationId,
    Iterable<Message> messages,
  ) {
    final ownerId = userName ?? '';
    if (ownerId.isEmpty) return List<Message>.from(messages);
    final hidden = _hiddenMessagesStore.load(ownerId, conversationId);
    if (hidden.isEmpty) return List<Message>.from(messages);
    return messages
        .where((message) => !hidden.contains(message.msgId))
        .toList();
  }

  // 群成员列表管理方法

  // 添加群成员列表
  void addGroupMembers(int groupId, List<GroupMemberModel> members) {
    _groupMemberCache.put(groupId, members);
  }

  // 获取群成员列表
  List<GroupMemberModel> getGroupMembers(int groupId) {
    return _groupMemberCache.get(groupId);
  }

  // 清除群成员列表
  void clearGroupMembers(int groupId) {
    _groupMemberCache.remove(groupId);
  }

  // 清除所有群成员列表
  void clearAllGroupMembers() {
    _groupMemberCache.clear();
  }

  //根据图片名生成图片的URL
  String getImageURL(String userName, String imageName) {
    if (token == null) {
      throw Exception('Token is null');
    }
    final baseUri = Uri.parse(baseURL);
    return baseUri
        .replace(
          path: '${baseUri.path}/api/image/download',
          queryParameters: {
            'key': token!,
            'userName': userName,
            'imageName': imageName,
          },
        )
        .toString();
  }

  // 根据视频名生成支持 HTTP Range 分段播放的视频 URL。
  String getVideoURL(String userName, String videoName) {
    final baseUri = Uri.parse(baseURL);
    return baseUri
        .replace(
          path: '${baseUri.path}/api/video/download',
          queryParameters: {'userName': userName, 'videoName': videoName},
        )
        .toString();
  }

  String getAudioURL(String userName, String audioName) {
    final baseUri = Uri.parse(baseURL);
    return baseUri
        .replace(
          path: '${baseUri.path}/api/audio/download',
          queryParameters: {'userName': userName, 'audioName': audioName},
        )
        .toString();
  }

  String getChatWebSocketURL(String userName) {
    final baseUri = Uri.parse(baseWebSocketURL);
    return baseUri
        .replace(
          path: '${baseUri.path}/api/chat',
          queryParameters: {'userName': userName},
        )
        .toString();
  }

  // 保存聊天记录到本地
  Future<void> saveChatRecordsToLocal(
    String myUserName,
    String otherUserName,
    List<Message> messages,
  ) async {
    try {
      await _chatLocalCache.save(
        myUserName,
        otherUserName,
        _filterHiddenMessages(otherUserName, messages),
      );
    } catch (e) {
      // 处理保存失败的情况
      if (kDebugMode) {
        debugPrint('保存聊天记录到本地失败: $e');
      }
      rethrow;
    }
  }

  // 从本地读取聊天记录到内存
  Future<List<Message>> loadChatRecordsFromLocal(
    String myUserName,
    String otherUserName,
  ) async {
    try {
      return _filterHiddenMessages(
        otherUserName,
        await _chatLocalCache.load(myUserName, otherUserName),
      );
    } catch (e) {
      // 处理读取失败的情况
      if (kDebugMode) {
        debugPrint('从本地读取聊天记录失败: $e');
      }
      return [];
    }
  }

  //获取当前时间戳
  static int getCurrentTimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  // 生成会话ID：将userName转换为数字比较大小，较大的放在前面
  static String generateSessionId(
    String currentUserName,
    String otherUserName,
  ) {
    String firstUserName;
    String secondUserName;

    try {
      // 尝试将userName转换为int进行比较
      int currentUserId = int.parse(currentUserName);
      int otherUserId = int.parse(otherUserName);

      if (currentUserId > otherUserId) {
        firstUserName = currentUserName;
        secondUserName = otherUserName;
      } else {
        firstUserName = otherUserName;
        secondUserName = currentUserName;
      }
    } catch (e) {
      // 如果转换失败，使用字母顺序排序作为备选方案
      List<String> userNames = [currentUserName, otherUserName];
      userNames.sort();
      firstUserName = userNames[1];
      secondUserName = userNames[0];
    }

    return '${firstUserName}_$secondUserName';
  }

  //将时间戳转成string时间格式
  static String formatTimestamp(
    int timestamp, {
    bool showMilliseconds = false,
  }) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final formatter = DateFormat('yyyy-MM-dd HH:mm:ss');
    return formatter.format(dateTime);
  }

  /// 聊天消息时间：当天显示时分，今年显示月日时分，往年显示年月日时分。
  static String formatChatTimestamp(int timestamp, {DateTime? referenceTime}) {
    return ChatTimeFormatter.format(timestamp, referenceTime: referenceTime);
  }

  //根据userName查找FriendInfoModel
  FriendInfoModel getFriendInfoByUserName(String userName) {
    final friendList = _userInfoModel?.friendListData ?? [];
    return friendList.firstWhere(
      (f) => f.userName == userName,
      orElse: () => FriendInfoModel.formJSON({'userName': userName}),
    );
  }

  bool hasFriend(String userName) {
    final normalizedUserName = userName.trim();
    if (normalizedUserName.isEmpty) return false;
    return (_userInfoModel?.friendListData ?? const <FriendInfoModel>[]).any(
      (friend) => friend.userName?.trim() == normalizedUserName,
    );
  }

  bool updateCachedFriendRemark(String userName, String remark) {
    final normalizedUserName = userName.trim();
    final friendList = _userInfoModel?.friendListData;
    if (normalizedUserName.isEmpty || friendList == null) return false;
    for (final friend in friendList) {
      if (friend.userName == normalizedUserName) {
        friend.remarks = remark.trim();
        return true;
      }
    }
    return false;
  }

  bool removeCachedFriend(String userName) {
    final normalizedUserName = userName.trim();
    final friendList = _userInfoModel?.friendListData;
    if (normalizedUserName.isEmpty || friendList == null) return false;
    final previousLength = friendList.length;
    friendList.removeWhere((friend) => friend.userName == normalizedUserName);
    return friendList.length != previousLength;
  }

  // 打开相册选择图片并上传头像
  Future<Uint8List?> selectAndUploadAvatar(String imageName) async {
    try {
      // 打开相册选择图片
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // 图片质量
        maxWidth: 800, // 最大宽度
        maxHeight: 800, // 最大高度
      );

      if (image == null) {
        // 用户取消了选择
        debugPrint("图片读取失败");
        return null;
      }

      // 获取当前用户名
      final String userName = this.userName ?? '';
      if (userName.isEmpty) {
        throw Exception('无法获取当前用户信息');
      }

      // 上传图片
      final imageLength = await image.length();
      if (imageLength > 5 * 1024 * 1024) {
        throw Exception('图片压缩后仍超过5MB，请选择较小的图片');
      }

      final bool isSuccess = await HttpUtil().uploadImageFile(
        imageName,
        image.path,
      );

      // 检查上传结果
      if (isSuccess) {
        // 上传成功，更新全局用户信息中的头像
        final UserInfoModel currentUserInfo = userInfoModel;
        userInfoModel = UserInfoModel(
          userName: currentUserInfo.userName,
          nickName: currentUserInfo.nickName,
          avatar: imageName, // 头像图片名
          gender: currentUserInfo.gender,
          region: currentUserInfo.region,
          signature: currentUserInfo.signature,
          friendListData: currentUserInfo.friendListData,
        );

        return image.readAsBytes();
      } else {
        throw Exception('上传失败');
      }
    } catch (e) {
      debugPrint('选择或上传头像失败: $e');
      return null;
    }
  }
}
