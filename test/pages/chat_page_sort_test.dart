import 'package:flutter_base/pages/mainPages/chatPage.dart';
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
}
