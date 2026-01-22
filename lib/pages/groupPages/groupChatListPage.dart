import 'package:flutter/material.dart';
import '../../utils/Gloabl.dart';

class GroupChat {
  final String groupId;
  final String name;
  final String avatar;

  GroupChat({required this.groupId, required this.name, required this.avatar});
}

class GroupChatListPage extends StatefulWidget {
  const GroupChatListPage({Key? key}) : super(key: key);

  @override
  _GroupChatListPageState createState() => _GroupChatListPageState();
}

class _GroupChatListPageState extends State<GroupChatListPage> {
  final List<GroupChat> _groupChats = [
    GroupChat(
      groupId: 'group1',
      name: '公司项目组',
      avatar: 'https://via.placeholder.com/40',
    ),
    GroupChat(
      groupId: 'group2',
      name: '大学同学群',
      avatar: 'https://via.placeholder.com/40',
    ),
    GroupChat(
      groupId: 'group3',
      name: '家族群',
      avatar: 'https://via.placeholder.com/40',
    ),
  ];

  GlobalUtil globalUtil = GlobalUtil();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('群聊'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: ListView.builder(
        itemCount: _groupChats.length,
        itemBuilder: (context, index) {
          final groupChat = _groupChats[index];
          return GestureDetector(
            onTap: () {
              // 导航到群聊对话框
              Navigator.pushNamed(
                context,
                '/groupChatDialog',
                arguments: {
                  'groupId': groupChat.groupId,
                  'groupName': groupChat.name,
                  'groupMembers': [], // 这里应该传递实际的群成员列表
                },
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1.0),
                ),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  // 群头像
                  Container(
                    width: 50.0,
                    height: 50.0,
                    margin: EdgeInsets.only(right: 12.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(groupChat.avatar),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // 群名
                  Text(
                    groupChat.name,
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
