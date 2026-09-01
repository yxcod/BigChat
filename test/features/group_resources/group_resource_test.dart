import 'dart:io';

import 'package:flutter_base/features/group_resources/data/group_resource_media_cache.dart';
import 'package:flutter_base/features/group_resources/domain/group_resource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses group file metadata and server delete permission', () {
    final resource = GroupResource.fromJson({
      'resourceId': '12',
      'groupId': 99,
      'resourceType': 1,
      'originalName': '演示.mp4',
      'mimeType': 'video/mp4',
      'fileSize': '1048576',
      'uploaderId': 'alice',
      'createdAt': 1770000000000,
      'canDelete': true,
      'hasCover': true,
      'coverLocalPath': '/cached/group/cover.jpg',
    });

    expect(resource.id, 12);
    expect(resource.type, GroupResourceType.file);
    expect(resource.canDelete, isTrue);
    expect(resource.fileSize, 1048576);
    expect(resource.hasCover, isTrue);
    expect(resource.coverLocalPath, '/cached/group/cover.jpg');
  });

  test('resource type 2 is parsed as album media', () {
    final resource = GroupResource.fromJson({
      'resourceId': 1,
      'groupId': 2,
      'resourceType': 2,
      'originalName': 'photo.jpg',
      'createdAt': 0,
      'canDelete': false,
    });

    expect(resource.type, GroupResourceType.album);
    expect(resource.canDelete, isFalse);
  });

  test('album video is identified from persisted mime type', () {
    final resource = GroupResource.fromJson({
      'resourceId': 2,
      'groupId': 2,
      'resourceType': 2,
      'originalName': 'clip.mov',
      'mimeType': 'video/quicktime',
      'createdAt': 0,
      'canDelete': true,
    });

    expect(resource.type, GroupResourceType.album);
    expect(resource.isVideo, isTrue);
    expect(resource.isImage, isFalse);
  });

  test(
    'an existing uploaded media path can be restored after restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'group_resource_media_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/resource.mp4');
      await file.writeAsBytes(const [1, 2, 3]);

      expect(
        const GroupResourceMediaCache().existingPath(file.path),
        file.path,
      );
      await file.delete();
      expect(const GroupResourceMediaCache().existingPath(file.path), isNull);
    },
  );
}
