import 'package:flutter_base/features/group_resources/data/group_resource_cache.dart';
import 'package:flutter_base/features/group_resources/domain/group_resource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'persists resource metadata by account, group, and album type',
    () async {
      final storage = <String, String>{};
      final cache = GroupResourceCache(
        readString: (key) => storage[key],
        writeString: (key, value) async => storage[key] = value,
      );
      final video = GroupResource(
        id: 1,
        groupId: 8,
        type: GroupResourceType.album,
        originalName: 'video.mp4',
        mimeType: 'video/mp4',
        fileSize: 1024,
        uploaderId: 'owner',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        canDelete: true,
      );

      await cache.save('owner', 8, GroupResourceType.album, [video]);

      expect(
        cache.load('owner', 8, GroupResourceType.album).single.isVideo,
        isTrue,
      );
      expect(cache.load('other', 8, GroupResourceType.album), isEmpty);
      expect(cache.load('owner', 8, GroupResourceType.file), isEmpty);
    },
  );
}
