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
    });

    expect(resource.id, 12);
    expect(resource.type, GroupResourceType.file);
    expect(resource.canDelete, isTrue);
    expect(resource.fileSize, 1048576);
  });

  test('resource type 2 is parsed as album photo', () {
    final resource = GroupResource.fromJson({
      'resourceId': 1,
      'groupId': 2,
      'resourceType': 2,
      'originalName': 'photo.jpg',
      'createdAt': 0,
      'canDelete': false,
    });

    expect(resource.type, GroupResourceType.photo);
    expect(resource.canDelete, isFalse);
  });
}
