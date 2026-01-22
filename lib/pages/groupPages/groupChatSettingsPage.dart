import 'package:flutter/material.dart';
import '../utils/Gloabl.dart';

class GroupChatSettingsPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<dynamic> groupMembers;

  const GroupChatSettingsPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    required this.groupMembers,
  }) : super(key: key);

  @override
  _GroupChatSettingsPageState createState() => _GroupChatSettingsPageState();
}

class _GroupChatSettingsPageState extends State<GroupChatSettingsPage> {
  GlobalUtil globalUtil = GlobalUtil();
  String _groupName = '';
  String _groupAnnouncement = '未设置';
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    // 模拟群成员数据
    _members = [
      {'id': '1', 'name': '刘仁杰', 'avatar': 'https://via.placeholder.com/40'},
      {'id': '2', 'name': '汪旭', 'avatar': 'https://via.placeholder.com/40'},
      {'id': '3', 'name': '祖航', 'avatar': 'https://via.placeholder.com/40'},
      {'id': '4', 'name': '夏星', 'avatar': 'https://via.placeholder.com/40'},
      {'id': '5', 'name': '陈子昊', 'avatar': 'https://via.placeholder.com/40'},
      {'id': '6', 'name': '耿良超', 'avatar': 'https://via.placeholder.com/40'},
      {'id': '7', 'name': '鹿铃', 'avatar': 'https://via.placeholder.com/40'},
      {'id': '8', 'name': '吴冠群', 'avatar': 'https://via.placeholder.com/40'},
    ];
  }

  void _editGroupName() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController(
          text: _groupName,
        );
        return AlertDialog(
          title: Text('编辑群聊名称'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: '请输入群聊名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text('确定'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _groupName = result;
      });
    }
  }

  void _editGroupAnnouncement() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        TextEditingController controller = TextEditingController(
          text: _groupAnnouncement == '未设置' ? '' : _groupAnnouncement,
        );
        return AlertDialog(
          title: Text('编辑群公告'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: '请输入群公告'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text('确定'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _groupAnnouncement = result.isEmpty ? '未设置' : result;
      });
    }
  }

  void _inviteMembers() {
    // 实现邀请成员功能
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('邀请成员'),
          content: Text('邀请成员功能待实现'),
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

  void _viewAllMembers() {
    // 实现查看所有成员功能
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('群聊成员'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(member['avatar']),
                  ),
                  title: Text(member['name']),
                  trailing: IconButton(
                    icon: Icon(Icons.more_vert),
                    onPressed: () {
                      // 实现成员管理功能（如移除成员）
                    },
                  ),
                );
              },
            ),
          ),
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

  void _exitGroup() {
    // 实现退出群聊功能
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('退出群聊'),
          content: Text('确定要退出该群聊吗？退出后将不再接收群消息。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // 退出群聊设置页面
                // 这里可以添加退出群聊的逻辑
              },
              child: Text('确定', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('群聊设置'),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 群聊基本信息
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1.0),
              ),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Container(
                  width: 60.0,
                  height: 60.0,
                  margin: EdgeInsets.only(right: 12.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage('https://via.placeholder.com/60'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _groupName,
                        style: TextStyle(
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        '在这里，发现更多~',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),

          // 群聊成员
          Container(
            margin: EdgeInsets.only(top: 12.0),
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '群聊成员',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap: _viewAllMembers,
                      child: Row(
                        children: [
                          Text(
                            '查看${_members.length}名成员',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey[600],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                            size: 16.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.0),
                Container(
                  height: 80.0,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12.0,
                      crossAxisSpacing: 12.0,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _members.length + 1, // +1 用于邀请按钮
                    itemBuilder: (context, index) {
                      if (index < _members.length) {
                        final member = _members[index];
                        return Column(
                          children: [
                            Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(member['avatar']),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            SizedBox(height: 4.0),
                            Text(
                              member['name'],
                              style: TextStyle(fontSize: 12.0),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      } else {
                        // 邀请按钮
                        return GestureDetector(
                          onTap: _inviteMembers,
                          child: Column(
                            children: [
                              Container(
                                width: 40.0,
                                height: 40.0,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                ),
                                child: Icon(Icons.add, color: Colors.grey[500]),
                              ),
                              SizedBox(height: 4.0),
                              Text(
                                '邀请',
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // 群聊信息
          Container(
            margin: EdgeInsets.only(top: 12.0),
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '群聊信息',
                  style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 12.0),

                // 群聊名称
                GestureDetector(
                  onTap: _editGroupName,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[100]!,
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '群聊名称',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey[800],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _groupName,
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.grey[600],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[400],
                              size: 16.0,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 群公告
                GestureDetector(
                  onTap: _editGroupAnnouncement,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[100]!,
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '群公告',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey[800],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _groupAnnouncement,
                              style: TextStyle(
                                fontSize: 14.0,
                                color: Colors.grey[600],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[400],
                              size: 16.0,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 我的本群昵称
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[100]!, width: 1.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '我的本群昵称',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[800],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            '未设置',
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.grey[600],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                            size: 16.0,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 退出群聊按钮
          Container(
            margin: EdgeInsets.only(top: 24.0, bottom: 32.0),
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: _exitGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: Size(double.infinity, 48.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: Text(
                '退出群聊',
                style: TextStyle(fontSize: 16.0, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
