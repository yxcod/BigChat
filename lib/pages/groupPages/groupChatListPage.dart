import 'package:flutter/material.dart';

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

  TextEditingController _searchController = TextEditingController();
  List<GroupChat> _filteredGroupChats = [];

  @override
  void initState() {
    super.initState();
    _filteredGroupChats = _groupChats;
  }

  void _filterGroupChats(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGroupChats = _groupChats;
      } else {
        _filteredGroupChats = _groupChats
            .where(
              (group) => group.name.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('群聊'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.pushNamed(context, '/groupCreatePage');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
            margin: EdgeInsets.all(16.0),
            padding: EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey[500], size: 20),
                SizedBox(width: 8.0),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterGroupChats,
                    decoration: InputDecoration(
                      hintText: '搜索群聊',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _filterGroupChats('');
                    },
                    child: Icon(Icons.clear, color: Colors.grey[500], size: 20),
                  ),
              ],
            ),
          ),
          // 群聊列表
          Expanded(
            child: ListView.builder(
              itemCount: _filteredGroupChats.length,
              itemBuilder: (context, index) {
                final groupChat = _filteredGroupChats[index];
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 12.0,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            Expanded(
                              child: Text(
                                groupChat.name,
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // 下划线，不覆盖头像
                        Container(
                          margin: EdgeInsets.only(left: 54.0, top: 12.0),
                          height: 1.0,
                          color: Colors.grey[200],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
