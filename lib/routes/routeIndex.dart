import 'package:flutter/material.dart';
import '../pages/LoginPages/loginWidget.dart';
import '../pages/mainPages/chatMainWidget.dart';
import '../pages/groupPages/groupChatListPage.dart';
import '../pages/groupPages/groupCreatePage.dart';
import '../pages/chatDialog.dart';
import '../pages/groupPages/groupChatDialog.dart';
import '../pages/groupPages/groupChatSettingsPage.dart';
import '../pages/groupPages/selectContactsPage.dart';
import '../pages/groupPages/selectGroupMembersToRemovePage.dart';
import '../pages/groupPages/groupMembersPage.dart';
import '../pages/friendManage/searchFriendPage.dart';
import '../pages/friendManage/friendDetailPage.dart';
import '../pages/friendManage/friendAddManagerPage.dart';
import '../pages/friendManage/addFriendRequestPage.dart';
import '../pages/profileEditPage.dart';
import '../pages/LoginPages/registerPage.dart';
import '../model/friendRequestModel.dart';
import '../features/moments/presentation/my_moments_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/notification_settings_page.dart';
import '../features/settings/presentation/sound_selection_page.dart';
import '../features/settings/data/app_settings_repository.dart';
import '../features/settings/domain/app_settings.dart';
import '../utils/gloabl.dart';
import '../api/getInfoAPI.dart';

int _parseIntRouteArgument(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Route<dynamic>? generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/chatDialog':
      // 确保路由参数被正确传递
      return MaterialPageRoute(
        builder: (context) => ChatDialogPage(),
        settings: settings, // 传递完整的路由设置，包括参数
      );
    case '/friendDetailPage':
      final friendData = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => FriendDetailPage(
          friendData: friendData,
          profileLoader: getUserInfoApi,
        ),
      );
    case '/addFriendRequestPage':
      final addUserData = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => AddFriendRequestPage(targetUser: addUserData),
      );
    case '/friendAddManagerPage':
      final friendReuqestData = settings.arguments as List<FriendRequestModel>;
      return MaterialPageRoute(
        builder: (context) =>
            FriendAddManagerPage(initialRequests: friendReuqestData),
      );
    case '/ProfileEditPage':
      final profileInfo = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => ProfileEditPage(profileInfo: profileInfo),
      );
    case '/myMoments':
      return MaterialPageRoute(builder: (context) => const MyMomentsPage());
    case '/settings':
      return MaterialPageRoute(builder: (context) => const SettingsPage());
    case '/notificationSettings':
      return MaterialPageRoute(
        builder: (context) => NotificationSettingsPage(
          repository: AppSettingsRepository(
            ownerId: GlobalUtil().userName ?? '',
          ),
        ),
      );
    case '/soundSelection':
      final selectedSoundId =
          settings.arguments?.toString() ?? NotificationSound.systemDefaultId;
      return MaterialPageRoute(
        builder: (context) =>
            SoundSelectionPage(selectedSoundId: selectedSoundId),
      );
    case '/groupChatDialog':
      final groupData = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => GroupChatDialogPage(
          groupId: _parseIntRouteArgument(groupData['groupId']),
          groupName: groupData['groupName']?.toString() ?? '',
        ),
      );
    case '/groupChatListPage':
      return MaterialPageRoute(builder: (context) => GroupChatListPage());
    case '/groupChatSettings':
      final groupData = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (context) => GroupChatSettingsPage(
          groupId: groupData['groupId'] ?? '',
          groupName: groupData['groupName'] ?? '',
          groupMembers: [],
        ),
      );
    case '/groupCreatePage':
      return MaterialPageRoute(builder: (context) => GroupCreatePage());
    case '/groupMembersPage':
      final groupData = settings.arguments as Map<String, dynamic>? ?? {};
      return MaterialPageRoute(
        builder: (context) => GroupMembersPage(
          groupId: groupData['groupId'] ?? 'default',
          groupName: groupData['groupName'] ?? '默认群聊',
        ),
      );
    case '/selectContactsPage':
      final groupData = settings.arguments as Map<String, dynamic>? ?? {};
      return MaterialPageRoute(
        builder: (context) =>
            SelectContactsPage(groupId: groupData['groupId'] ?? ''),
      );
    case '/selectGroupMembersToRemovePage':
      final groupData = settings.arguments as Map<String, dynamic>? ?? {};
      return MaterialPageRoute(
        builder: (context) =>
            SelectGroupMembersToRemovePage(groupId: groupData['groupId'] ?? ''),
      );
    default:
      return null;
  }
}

Map<String, Widget Function(BuildContext)> getRoutes() {
  return {
    "/login": (context) => BigchatLoginPage(),
    '/mainWidget': (context) => BigchatMainPage(),
    '/searchFriendPage': (context) => SearchFriendPage(),
    '/registerPage': (context) => RegisterPage(),
  };
}
