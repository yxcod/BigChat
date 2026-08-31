import 'package:flutter/material.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_base/features/moments/domain/moment.dart';
import 'package:flutter_base/model/userInfoModel.dart';
import 'package:flutter_base/pages/mainPages/profilePage.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('我的页展示紧凑资料、真实动态统计和模糊设置说明', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = UserInfoModel(
      userName: '13800138000',
      nickName: '叶翔',
      avatar: '',
      gender: 1,
      region: '浙江省 杭州市',
      signature: '保持热爱，奔赴山海',
      friendListData: const [],
    );
    GlobalUtil().userName = '13800138000';
    GlobalUtil().userInfoModel = profile;

    final moments = [
      _moment(id: '1', likeCount: 8),
      _moment(id: '2', likeCount: 3),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ProfilePage(
          initialProfile: profile,
          initialMoments: moments,
          autoLoad: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('我的'), findsOneWidget);
    expect(find.byKey(const Key('profile_summary_card')), findsOneWidget);
    expect(find.byKey(const Key('edit_profile_button')), findsOneWidget);
    expect(find.text('账号：13800138000'), findsOneWidget);
    expect(find.text('男 · 浙江省 杭州市'), findsOneWidget);
    expect(find.text('保持热爱，奔赴山海'), findsOneWidget);
    expect(find.byKey(const Key('my_space_card')), findsOneWidget);
    expect(find.text('动态 2 · 获赞 11'), findsOneWidget);
    expect(find.text('还没有带图片的动态'), findsOneWidget);
    expect(find.text('偏好设置与更多'), findsOneWidget);
    expect(find.text('关于全信'), findsOneWidget);
    expect(find.text('资料编辑'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Moment _moment({required String id, required int likeCount}) {
  return Moment(
    id: id,
    authorId: '13800138000',
    authorName: '叶翔',
    authorAvatarUrl: '',
    content: '动态$id',
    mediaPaths: const [],
    createdAt: DateTime(2026, 8, 25),
    visibility: MomentVisibility.public,
    location: null,
    likeCount: likeCount,
    isLiked: false,
    comments: const [],
  );
}
