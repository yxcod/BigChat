import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/storageUtil.dart';
import '../model/userInfoModel.dart';
import '../model/friendInfoModel.dart';
import '../model/messageModel.dart';
import '../utils/http.dart';
import '../api/getChatMessagesAPI.dart';

class GlobalUtil {
  static const String _baseURL = 'http://45.197.144.95:5555';
  //static const String _baseURL = 'https://989cd2489iw2.vicp.fun';

  static const String _baseWebSocketURL = 'ws://45.197.144.95:5555';
  //static const String _baseWebSocketURL = 'ws://989cd2489iw2.vicp.fun';
  String? _token;
  String? _userName;
  bool? _isLoading;
  UserInfoModel? _userInfoModel;
  bool? _isChatting;
  String? _currentChatUserName;
  Function(String, int)? onUnreadCountChanged;

  // 存储每个聊天对象的未读消息ID列表
  final Map<String, List<int>> _unreadMessages = {};

  // 存储每个聊天对象的未读消息总数
  final Map<String, int> _unreadCounts = {};

  // 存储所有聊天记录，以userName为key
  final Map<String, List<Message>> _chatRecords = {};

  static final GlobalUtil _instance = GlobalUtil._internal();
  factory GlobalUtil() {
    return _instance;
  }
  GlobalUtil._internal();

  UserInfoModel get userInfoModel =>
      _userInfoModel ?? UserInfoModel.formJSON({});
  String get baseURL => _baseURL;
  String get baseWebSocketURL => _baseWebSocketURL;
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
    _userName = value;
    if (value != null) {
      StorageUtil.setString('global_userName', value);
    }
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
    if (!_unreadMessages.containsKey(userName)) {
      _unreadMessages[userName] = [];
      _unreadCounts[userName] = 0;
    }
    _unreadMessages[userName]!.add(msgId);
    _unreadCounts[userName] = (_unreadCounts[userName] ?? 0) + 1;
    final count = _unreadCounts[userName]!;

    // 通知未读消息数变化，使用addPostFrameCallback确保不在构建过程中调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onUnreadCountChanged?.call(userName, count);
    });
  }

  // 获取某个用户的所有未读消息ID
  List<int> getUnreadMessages(String userName) {
    return _unreadMessages[userName] ?? [];
  }

  // 清除某个用户的所有未读消息
  void clearUnreadMessages(String userName) {
    _unreadMessages.remove(userName);
    _unreadCounts.remove(userName);

    // 通知未读消息数变化，使用addPostFrameCallback确保不在构建过程中调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onUnreadCountChanged?.call(userName, 0);
    });
  }

  // 获取某个用户的未读消息数
  int getUnreadCount(String userName) {
    return _unreadCounts[userName] ?? 0;
  }

  // 聊天记录管理方法

  // 添加消息到聊天记录
  void addMessage(String userName, Message message) {
    _chatRecords.putIfAbsent(userName, () => []);
    _chatRecords[userName]!.add(message);
  }

  // 获取某个用户的所有聊天记录
  List<Message> getChatRecords(String userName) {
    return _chatRecords[userName] ?? [];
  }

  // 获取聊天记录的当前加载数量
  int getChatRecordsCount(String userName) {
    return _chatRecords[userName]?.length ?? 0;
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
        count: count,
      );

      // 检查是否有新记录：只有当获取到的记录数量小于1时，才认为没有更多记录了
      // 这样修改是因为后端可能返回少于请求数量的记录（例如当接近记录末尾时）
      if (messageModels.length < 1) {
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
      _chatRecords[userName] = messages;

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
    _chatRecords.remove(userName);
  }

  // 清除所有聊天记录
  void clearAllChatRecords() {
    _chatRecords.clear();
  }

  // 标记特定消息为已读
  void markMessageAsRead(String userName, int msgId) {
    if (_chatRecords.containsKey(userName)) {
      List<Message> messages = _chatRecords[userName]!;
      for (var message in messages) {
        if (message.msgId == msgId) {
          message.isRead = true;
          message.status = MessageStatus.read;
          break;
        }
      }
    }
  }

  // 标记所有消息为已读
  void markAllMessagesAsRead(String userName) {
    if (_chatRecords.containsKey(userName)) {
      List<Message> messages = _chatRecords[userName]!;
      for (var message in messages) {
        if (!message.isMe) {
          message.isRead = true;
          message.status = MessageStatus.read;
        }
      }
    }
  }

  // 删除指定消息
  void deleteMessage(String userName, int msgId) {
    if (_chatRecords.containsKey(userName)) {
      List<Message> messages = _chatRecords[userName]!;
      messages.removeWhere((message) => message.msgId == msgId);
    }
  }

  //根据图片名生成图片的URL
  String getImageURL(String userName, String imageName) {
    if (token == null) {
      throw Exception('Token is null');
    }
    return '$baseURL/api/image/download?key=$token&userName=$userName&imageName=$imageName';
  }

  // 保存聊天记录到本地
  Future<void> saveChatRecordsToLocal(
    String myUserName,
    String otherUserName,
    List<Message> messages,
  ) async {
    // 生成唯一的存储key，确保相同的两个用户无论顺序如何都使用相同的key
    final sessionKey = generateSessionId(myUserName, otherUserName);
    final storageKey = 'chat_records_$sessionKey';

    try {
      // 将Message数组序列化为JSON字符串
      final messagesJson = messages.map((msg) => msg.toJSON()).toList();
      final jsonString = jsonEncode(messagesJson);

      // 保存到本地存储
      await StorageUtil.setString(storageKey, jsonString);
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
    // 生成唯一的存储key
    final sessionKey = generateSessionId(myUserName, otherUserName);
    final storageKey = 'chat_records_$sessionKey';

    try {
      // 从本地存储读取JSON字符串
      final jsonString = StorageUtil.getString(storageKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      // 将JSON字符串反序列化为Message数组
      final messagesJson = jsonDecode(jsonString) as List<dynamic>;
      final messages = messagesJson
          .map((msgJson) => Message.fromJSON(msgJson as Map<String, dynamic>))
          .toList();

      return messages;
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

  //根据userName查找FriendInfoModel
  FriendInfoModel getFriendInfoByUserName(String userName) {
    final friendList = _userInfoModel?.friendListData ?? [];
    return friendList.firstWhere(
      (f) => f.userName == userName,
      orElse: () => FriendInfoModel.formJSON({'userName': userName}),
    );
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

      // 将图片转换为Uint8List
      final Uint8List imageData = await image.readAsBytes();

      // 获取当前用户名
      final String userName = this.userName ?? '';
      if (userName.isEmpty) {
        throw Exception('无法获取当前用户信息');
      }

      // 上传图片
      final bool isSuccess = await HttpUtil().uploadImage(imageName, imageData);

      // 检查上传结果
      if (isSuccess) {
        // 上传成功，更新全局用户信息中的头像
        final UserInfoModel currentUserInfo = userInfoModel;
        userInfoModel = UserInfoModel(
          userName: currentUserInfo.userName,
          nickName: currentUserInfo.nickName,
          avatar: imageName, // 头像图片名
          signature: currentUserInfo.signature,
          friendListData: currentUserInfo.friendListData,
        );

        return imageData; // 返回图片数据
      } else {
        throw Exception('上传失败');
      }
    } catch (e) {
      print('选择或上传头像失败: $e');
      return null;
    }
  }
}
