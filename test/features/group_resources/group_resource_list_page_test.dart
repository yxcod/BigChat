import 'package:flutter/material.dart';
import 'package:flutter_base/features/group_resources/data/group_resource_repository.dart';
import 'package:flutter_base/features/group_resources/domain/group_resource.dart';
import 'package:flutter_base/features/group_resources/presentation/group_resource_list_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('group album offers both photo and video uploads', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GroupResourceListPage(
          groupId: 8,
          groupName: '测试群',
          type: GroupResourceType.album,
          repository: _EmptyGroupResourceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无群照片或视频'), findsOneWidget);
    expect(find.text('上传照片或视频'), findsOneWidget);

    await tester.tap(find.text('上传照片或视频'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group_album_upload_photo')), findsOneWidget);
    expect(find.byKey(const Key('group_album_upload_video')), findsOneWidget);
    expect(find.textContaining('MP4、MOV、M4V'), findsOneWidget);
  });

  testWidgets('cached files remain visible when background refresh fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GroupResourceListPage(
          groupId: 8,
          groupName: '测试群',
          type: GroupResourceType.file,
          repository: _OfflineCachedGroupResourceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('离线文件.pdf'), findsOneWidget);
  });
}

class _EmptyGroupResourceRepository extends GroupResourceRepository {
  @override
  Future<List<GroupResource>> list(int groupId, GroupResourceType type) async =>
      const [];
}

class _OfflineCachedGroupResourceRepository extends GroupResourceRepository {
  @override
  List<GroupResource> loadCached(int groupId, GroupResourceType type) => [
    GroupResource(
      id: 2,
      groupId: groupId,
      type: type,
      originalName: '离线文件.pdf',
      mimeType: 'application/pdf',
      fileSize: 2048,
      uploaderId: 'owner',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      canDelete: false,
    ),
  ];

  @override
  Future<List<GroupResource>> list(int groupId, GroupResourceType type) async {
    throw Exception('offline');
  }
}
