import 'package:flutter_base/features/groups/application/group_member_cache.dart';
import 'package:flutter_base/model/groupMemberModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GroupMemberCache copies input and protects cached collections', () {
    final cache = GroupMemberCache();
    final source = [GroupMemberModel(userId: '1', groupNickName: 'Alice')];

    cache.put(10, source);
    source.add(GroupMemberModel(userId: '2', groupNickName: 'Bob'));

    expect(cache.get(10).map((member) => member.userId), ['1']);
    expect(
      () => cache.get(10).add(GroupMemberModel(userId: '3')),
      throwsUnsupportedError,
    );

    cache.remove(10);
    expect(cache.get(10), isEmpty);
  });

  test('GroupMemberCache clears all groups', () {
    final cache = GroupMemberCache();
    cache.put(10, [GroupMemberModel(userId: '1')]);
    cache.put(20, [GroupMemberModel(userId: '2')]);

    cache.clear();

    expect(cache.get(10), isEmpty);
    expect(cache.get(20), isEmpty);
  });
}
