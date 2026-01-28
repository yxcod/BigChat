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

Widget getRootWidget() {
  return MaterialApp(
    initialRoute: "/login",
    routes: getRoutes(),
    // 使用 onGenerateRoute 处理需要传递参数的路由
    onGenerateRoute: (settings) {
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
            builder: (context) => FriendDetailPage(friendData: friendData),
          );
        case '/addFriendRequestPage':
          final addUserData = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => AddFriendRequestPage(targetUser: addUserData),
          );
        case '/friendAddManagerPage':
          final friendReuqestData =
              settings.arguments as List<FriendRequestModel>;
          return MaterialPageRoute(
            builder: (context) =>
                FriendAddManagerPage(initialRequests: friendReuqestData),
          );
        case '/ProfileEditPage':
          final profileInfo = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => ProfileEditPage(profileInfo: profileInfo),
          );
        case '/groupChatDialog':
          final groupData = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => GroupChatDialogPage(
              groupId: groupData['groupId'] ?? '',
              groupName: groupData['groupName'] ?? '',
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
            builder: (context) => SelectGroupMembersToRemovePage(
              groupId: groupData['groupId'] ?? '',
            ),
          );
        default:
          return null;
      }
    },
  );
}

Map<String, Widget Function(BuildContext)> getRoutes() {
  return {
    "/login": (context) => BigchatLoginPage(),
    '/mainWidget': (context) => BigchatMainPage(),
    '/searchFriendPage': (context) => SearchFriendPage(),
    '/registerPage': (context) => RegisterPage(),
    '/groupMembersPage': (context) =>
        GroupMembersPage(groupId: 'default', groupName: '默认群聊'),
  };
}
