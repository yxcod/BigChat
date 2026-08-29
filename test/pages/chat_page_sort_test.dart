import 'package:flutter_base/pages/mainPages/chatPage.dart';
import 'package:flutter_base/model/messageModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('会话按更新时间从新到旧排序', () {
    Chat chat(String id, int updateTime) => Chat(
      name: id,
      avatar: '',
      lastMessage: '',
      time: '',
      unreadCount: 0,
      userName: id,
      updateTime: updateTime,
    );

    final sorted = sortChatsByLatest([
      chat('middle', 200),
      chat('oldest', 100),
      chat('latest', 300),
    ]);

    expect(sorted.map((item) => item.userName), ['latest', 'middle', 'oldest']);
  });

  test('内存隐私消息可以更新会话摘要而不丢失其它状态', () {
    final original = Chat(
      name: '测试群',
      avatar: 'avatar.png',
      lastMessage: '旧消息',
      time: '09:00',
      unreadCount: 1,
      userName: '5',
      isGroup: true,
      lastSenderName: '旧成员',
      updateTime: 1000,
    );

    final updated = original.copyWith(
      lastMessage: '隐私消息正文',
      time: '10:00',
      lastSenderName: '新成员',
      updateTime: 2000,
    );

    expect(updated.lastMessage, '隐私消息正文');
    expect(updated.time, '10:00');
    expect(updated.lastSenderName, '新成员');
    expect(updated.updateTime, 2000);
    expect(updated.unreadCount, 1);
  });

  test('本地删除最新消息后会话摘要回退到实际最后一条', () {
    final chat = Chat(
      name: '测试用户',
      avatar: '',
      lastMessage: '已删除的新消息',
      time: '10:20',
      unreadCount: 0,
      userName: 'friend',
      updateTime: 2000,
    );
    final remaining = Message(
      msgId: 10,
      content: '仍然存在的上一条消息',
      isMe: true,
      time: '',
      isRead: true,
      conversationId: 'conversation',
      timestamp: 1000,
    );

    final updated = applyVisibleLocalMessagePreview(chat, [remaining]);

    expect(updated.lastMessage, '仍然存在的上一条消息');
    expect(updated.updateTime, 1000);
  });

  test('本地删除会话内全部消息后清空会话摘要', () {
    final chat = Chat(
      name: '测试群',
      avatar: '',
      lastMessage: '已删除的消息',
      time: '10:20',
      unreadCount: 0,
      userName: '8',
      isGroup: true,
      lastSenderName: '某成员',
      updateTime: 2000,
    );

    final updated = applyVisibleLocalMessagePreview(chat, const []);

    expect(updated.lastMessage, isEmpty);
    expect(updated.time, isEmpty);
    expect(updated.lastSenderName, isNull);
    expect(updated.updateTime, 0);
  });
}
