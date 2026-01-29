import 'package:flutter/material.dart';
import 'friendsPage.dart';
import 'chatPage.dart';
import 'ProfilePage.dart';
import '../../api/getChatMessagesAPI.dart';
import '../../utils/Gloabl.dart';
import '../../model/messageModel.dart';

class BigchatMainPage extends StatefulWidget {
  @override
  _BigchatMainPageState createState() => _BigchatMainPageState();
}

class _BigchatMainPageState extends State<BigchatMainPage> {
  final List<Friend> _friends = [];
  final List<Chat> _chats = [];

  int _currentIndex = 1;
  int _totalUnreadCount = 0;

  void _onUnreadCountChanged(int count) {
    setState(() {
      _totalUnreadCount = count;
    });
  }

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      Chatpage(chatList: _chats, onUnreadCountChanged: _onUnreadCountChanged),
      Friendspage(friendListDate: _friends),
      ProfilePage(),
    ];

    // 在页面构建完成后获取未读消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUnreadMessages();

      // 检查是否有被移除群聊的信号
      final ModalRoute<dynamic>? route = ModalRoute.of(context);
      if (route != null && route.settings.arguments != null) {
        final arguments = route.settings.arguments as Map<String, dynamic>;
        if (arguments.containsKey('isRemovedFromGroup') &&
            arguments['isRemovedFromGroup'] == true) {
          // 显示被移除群聊的弹窗提示
          _showRemovedFromGroupDialog();
        }
      }
    });
  }

  // 显示被移除群聊的弹窗提示
  void _showRemovedFromGroupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('提示'),
          content: Text('您已被移除出群聊'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 不再在chatMainWidget中直接加载聊天记录，而是由chatPage在获取会话列表后负责加载

  // 获取未读消息
  Future<void> _fetchUnreadMessages() async {
    try {
      final globalUtil = GlobalUtil();
      final userName = globalUtil.userName;

      if (userName == null) {
        debugPrint('当前用户未登录，无法获取未读消息');
        return;
      }

      debugPrint('正在获取未读消息...');
      final List<MessageModel> unreadMessages = await getUnReadChatMessagesApi(
        userName: userName,
      );

      debugPrint('获取到未读消息：${unreadMessages.length}条');

      // 处理未读消息
      for (MessageModel message in unreadMessages) {
        // 确保senderName和receiverName不为空
        final senderName = message.senderName ?? '';
        if (senderName.isEmpty) {
          debugPrint('跳过无效的消息：$message');
          continue;
        }

        // 将消息添加到全局聊天记录
        globalUtil.addMessage(
          senderName,
          Message(
            msgId: message.msgId!,
            content: message.content ?? '',
            isMe: false,
            time: GlobalUtil.formatTimestamp(
              message.timestamp ?? DateTime.now().millisecondsSinceEpoch,
            ),
            isRead: true, // 未读消息
            conversationId: message.conversationId ?? '',
            messageType: message.messageType!,
            status: message.messageStatus!,
          ),
        );

        // 添加到未读消息列表
        globalUtil.addUnreadMessage(senderName, message.msgId!);
      }

      debugPrint('未读消息处理完成');
    } catch (e) {
      debugPrint('获取未读消息失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                Icon(Icons.chat),
                if (_totalUnreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: BoxConstraints(minWidth: 12, minHeight: 12),
                      child: Text(
                        _totalUnreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: '聊天',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '好友'),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
