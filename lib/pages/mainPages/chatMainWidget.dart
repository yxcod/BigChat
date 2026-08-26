import 'package:flutter/material.dart';
import 'friendsPage.dart';
import 'chatPage.dart';
import 'ProfilePage.dart';
import '../../api/getChatMessagesAPI.dart';
import '../../utils/gloabl.dart';
import '../../model/messageModel.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';

class BigchatMainPage extends StatefulWidget {
  const BigchatMainPage({super.key, this.autoRefresh = true});

  final bool autoRefresh;

  @override
  State<BigchatMainPage> createState() => _BigchatMainPageState();
}

class _BigchatMainPageState extends State<BigchatMainPage>
    with WidgetsBindingObserver {
  final List<Friend> _friends = [];
  final List<Chat> _chats = [];

  int _currentIndex = 0;
  int _totalUnreadCount = 0;
  bool _wasBackgrounded = false;

  void _onUnreadCountChanged(int count) {
    setState(() {
      _totalUnreadCount = count;
    });
  }

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = [
      Chatpage(
        chatList: _chats,
        onUnreadCountChanged: _onUnreadCountChanged,
        autoRefresh: widget.autoRefresh,
      ),
      Friendspage(friendListDate: _friends, autoRefresh: widget.autoRefresh),
      const ProfilePage(),
    ];

    // 在页面构建完成后获取未读消息
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoRefresh) _fetchUnreadMessages();

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasBackgrounded = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      if (_currentIndex != 0 && mounted) {
        setState(() => _currentIndex = 0);
      }
    }
  }

  // 显示被移除群聊的弹窗提示
  void _showRemovedFromGroupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('提示'),
          content: Text(
            (ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?)?['message']
                    ?.toString() ??
                '您已被移出该群聊',
          ),
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
            time: GlobalUtil.formatChatTimestamp(
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
          FocusManager.instance.primaryFocus?.unfocus();
          GlobalUtil().isOnChatTab = (index == 0);
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: context.appSurface,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: context.appTextSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: [
          BottomNavigationBarItem(
            icon: _buildNavigationIcon(
              icon: Icons.chat_bubble_outline_rounded,
              selected: false,
              unreadCount: _totalUnreadCount,
            ),
            activeIcon: _buildNavigationIcon(
              icon: Icons.chat_bubble_rounded,
              selected: true,
              unreadCount: _totalUnreadCount,
            ),
            label: '聊天',
          ),
          BottomNavigationBarItem(
            icon: _buildNavigationIcon(
              icon: Icons.person_outline_rounded,
              selected: false,
            ),
            activeIcon: _buildNavigationIcon(
              icon: Icons.person_rounded,
              selected: true,
            ),
            label: '好友',
          ),
          BottomNavigationBarItem(
            icon: _buildNavigationIcon(
              icon: Icons.account_circle_outlined,
              selected: false,
            ),
            activeIcon: _buildNavigationIcon(
              icon: Icons.account_circle_rounded,
              selected: true,
            ),
            label: '我的',
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationIcon({
    required IconData icon,
    required bool selected,
    int unreadCount = 0,
  }) {
    return SizedBox(
      width: 52,
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 32,
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEAF8F0) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 23,
              color: selected ? AppColors.primary : context.appTextSecondary,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                key: const ValueKey('main_chat_unread_badge'),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appSurface, width: 1.5),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
