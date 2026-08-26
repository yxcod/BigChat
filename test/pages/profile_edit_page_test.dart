import 'package:flutter/material.dart';
import 'package:flutter_base/model/userInfoModel.dart';
import 'package:flutter_base/pages/profileEditPage.dart';
import 'package:flutter_base/pages/region_editor_page.dart';
import 'package:flutter_base/utils/gloabl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final global = GlobalUtil();
    global.userName = 'current-user';
    global.token = 'test-token';
    global.userInfoModel = UserInfoModel(
      userName: 'current-user',
      nickName: '叶翔',
      avatar: 'head.jpg',
      gender: 1,
      region: '山东省 济南市',
      signature: '快看看',
      friendListData: const [],
    );
  });

  testWidgets('资料编辑页使用紧凑列表且头像行没有箭头', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileEditPage(
          profileInfo: {
            'nickName': '叶翔',
            'gender': 1,
            'region': '山东省 济南市',
            'signature': '快看看',
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('编辑资料'), findsOneWidget);
    expect(find.text('更换头像'), findsOneWidget);
    expect(find.text('性别'), findsOneWidget);
    expect(find.text('地区'), findsOneWidget);
    expect(find.text('山东省 济南市'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(4));

    await tester.tap(find.byKey(const Key('edit_gender_row')));
    await tester.pump(const Duration(milliseconds: 500));
    final femaleOption = find.byKey(const Key('gender_option_2'));
    tester.widget<ListTile>(femaleOption).onTap?.call();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('女'), findsOneWidget);
  });

  testWidgets('地区支持定位填充和手动编辑到市', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => RegionEditorPage(
                    initialRegion: '',
                    cityLocator: () async => '广东省 深圳市',
                  ),
                ),
              );
            },
            child: const Text('打开地区编辑'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开地区编辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('use_current_location_button')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const Key('region_manual_field')),
    );
    expect(field.maxLength, 8);
    expect(field.controller?.text, '广东省 深圳市');

    await tester.enterText(
      find.byKey(const Key('region_manual_field')),
      '浙江省 杭州市',
    );
    await tester.tap(find.byKey(const Key('region_complete_button')));
    await tester.pumpAndSettle();
    expect(result, '浙江省 杭州市');
  });

  testWidgets('昵称编辑限制为10个字', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProfileEditPage(
          profileInfo: {
            'nickName': '叶翔',
            'gender': 1,
            'region': '北京市',
            'signature': '',
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('edit_nickname_row')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, 10);
    await tester.enterText(find.byType(TextField), '一二三四五六七八九十十一');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '一二三四五六七八九十',
    );
  });
}
