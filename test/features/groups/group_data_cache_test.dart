import 'package:flutter_base/features/groups/data/group_data_cache.dart';
import 'package:flutter_base/model/groupInfoModel.dart';
import 'package:flutter_base/model/groupMemberModel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists groups and members per account and group', () async {
    final storage = <String, String>{};
    final cache = GroupDataCache(
      readString: (key) => storage[key],
      writeString: (key, value) async => storage[key] = value,
      deleteString: (key) async => storage.remove(key),
    );

    await cache.saveGroups('owner', [
      GroupInfoModel(groupId: 8, groupName: '缓存群', creatorId: 'owner'),
    ]);
    await cache.saveMembers('owner', 8, [
      GroupMemberModel(groupId: 8, userId: 'owner', groupNickName: '群主'),
    ]);

    expect(cache.loadGroups('owner').single.groupName, '缓存群');
    expect(cache.loadMembers('owner', 8).single.groupNickName, '群主');
    expect(cache.loadGroups('other'), isEmpty);
    expect(cache.loadMembers('owner', 9), isEmpty);

    await cache.removeMembers('owner', 8);
    expect(cache.loadMembers('owner', 8), isEmpty);
  });
}
