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
}
