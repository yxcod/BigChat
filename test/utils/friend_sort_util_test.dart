import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_base/utils/friend_sort_util.dart';

void main() {
  int compare(
    ({bool online, String name, String userName}) left,
    ({bool online, String name, String userName}) right,
  ) {
    return FriendSortUtil.compare(
      leftOnline: left.online,
      leftDisplayName: left.name,
      leftUserName: left.userName,
      rightOnline: right.online,
      rightDisplayName: right.name,
      rightUserName: right.userName,
    );
  }

  test('在线好友始终排列在离线好友前面', () {
    final friends = [
      (online: false, name: '阿离', userName: 'offline'),
      (online: true, name: '张三', userName: 'online'),
    ]..sort(compare);

    expect(friends.map((friend) => friend.userName), ['online', 'offline']);
  });

  test('同一在线状态按备注或昵称的中文拼音首字母排序', () {
    final friends = [
      (online: true, name: '张三', userName: 'zhang'),
      (online: true, name: '陈晨', userName: 'chen'),
      (online: true, name: '李四', userName: 'li'),
    ]..sort(compare);

    expect(friends.map((friend) => friend.userName), ['chen', 'li', 'zhang']);
  });

  test('空显示名回退到账户名并保持稳定排序', () {
    final friends = [
      (online: false, name: '', userName: 'beta'),
      (online: false, name: '', userName: 'alpha'),
    ]..sort(compare);

    expect(friends.map((friend) => friend.userName), ['alpha', 'beta']);
  });

  test('好友索引兼容中文拼音、英文和无法识别的名称', () {
    expect(FriendSortUtil.initial(displayName: '张三', userName: 'zhang'), 'Z');
    expect(FriendSortUtil.initial(displayName: '', userName: 'alice'), 'A');
    expect(FriendSortUtil.initial(displayName: '🙂', userName: 'emoji'), '#');
  });
}
