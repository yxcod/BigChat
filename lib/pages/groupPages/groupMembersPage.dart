import 'package:flutter/material.dart';

class GroupMembersPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupMembersPage({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  _GroupMembersPageState createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _groupMembers = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  //List<String> _userFriends = []; // 模拟用户好友列表，存储好友的userId

  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
    _loadUserFriends();
  }

  void _loadGroupMembers() {
    // 模拟加载群成员数据
    _groupMembers = [
      {
        'id': '1',
        'name': '王刚强',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': true,
      },
      {
        'id': '2',
        'name': '鹿铃',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': true,
      },
      {
        'id': '3',
        'name': '刘仁杰',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': true,
      },
      {
        'id': '4',
        'name': '南风',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': false,
      },
      {
        'id': '5',
        'name': '张蕾蕾',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': true,
      },
      {
        'id': '6',
        'name': '@琪冰',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': false,
      },
      {
        'id': '7',
        'name': '汪旭',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': true,
      },
      {
        'id': '8',
        'name': '祖航',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': true,
      },
      {
        'id': '9',
        'name': '夏星',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': false,
      },
      {
        'id': '10',
        'name': '陈子昊',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': true,
      },
      {
        'id': '11',
        'name': '耿良超',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': false,
      },
      {
        'id': '12',
        'name': '吴冠群',
        'avatar': 'https://via.placeholder.com/40',
        'isFriend': true,
      },
    ];
    _filteredMembers = _groupMembers;
  }

  void _loadUserFriends() {
    // 模拟加载用户好友列表
    //_userFriends = ['1', '2', '3', '5', '7', '8', '10', '12'];
  }

  void _filterMembers(String query) {
    if (query.isEmpty) {
      _filteredMembers = _groupMembers;
    } else {
      _filteredMembers = _groupMembers.where((member) {
        return member['name'].toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  void _addFriend(String userId) {
    // 模拟添加好友操作
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('添加好友'),
          content: Text('发送好友请求成功'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('群聊成员'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.sort),
            onPressed: () {
              // 排序功能
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              // 更多功能
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterMembers,
              decoration: InputDecoration(
                hintText: '搜索',
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // 群成员列表
          Expanded(
            child: ListView.builder(
              itemCount: _filteredMembers.length,
              itemBuilder: (context, index) {
                final member = _filteredMembers[index];
                bool isFriend = member['isFriend'] ?? false;

                return Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[100]!, width: 1.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 头像
                      Container(
                        width: 40.0,
                        height: 40.0,
                        margin: EdgeInsets.only(right: 12.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: NetworkImage(member['avatar']),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // 昵称
                      Expanded(
                        child: Text(
                          member['name'],
                          style: TextStyle(fontSize: 16.0),
                        ),
                      ),

                      // 添加按钮（仅当非好友时显示）
                      if (!isFriend) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 6.0,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: Colors.green, width: 1.0),
                          ),
                          child: GestureDetector(
                            onTap: () => _addFriend(member['id']),
                            child: Text(
                              '添加',
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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
