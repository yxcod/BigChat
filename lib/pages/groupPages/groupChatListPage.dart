import 'package:flutter/material.dart';
import 'dart:async';
import '../../utils/gloabl.dart';
import '../../api/getGroupInfoAPI.dart';
import '../../model/groupInfoModel.dart';

String _addTimestamp(String url) {
  if (url.isEmpty || !url.startsWith('http')) return url;
  final ts = DateTime.now().millisecondsSinceEpoch;
  final sep = url.contains('?') ? '&' : '?';
  return '$url${sep}_=$ts';
}

class GroupChat {
  final String groupId;
  final String name;
  final String avatar;
  final String previousAvatar;

  GroupChat({
    required this.groupId,
    required this.name,
    required this.avatar,
    required this.previousAvatar,
  });

  factory GroupChat.fromGroupInfoModel(GroupInfoModel model) {
    return GroupChat(
      groupId: model.groupId.toString(),
      name: model.groupName,
      avatar: model.groupAvatar, // 默认头像，可根据实际情况修改
      previousAvatar: '',
    );
  }
}

class GroupChatListPage extends StatefulWidget {
  const GroupChatListPage({Key? key}) : super(key: key);

  @override
  _GroupChatListPageState createState() => _GroupChatListPageState();
}

class _GroupChatListPageState extends State<GroupChatListPage> {
  GlobalUtil globalUtil = GlobalUtil();
  List<GroupChat> _groupChats = [];
  Map<String, String> previousAvatars = {};
  TextEditingController _searchController = TextEditingController();
  List<GroupChat> _filteredGroupChats = [];
  late Timer _timer;
  @override
  void initState() {
    super.initState();
    _filteredGroupChats = _groupChats;
    // 初始化时获取一次群聊数据
    _fetchGroups();
    // 设置定时器，每秒获取一次群聊数据
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _fetchGroups();
    });
  }

  @override
  void dispose() {
    // 清理定时器
    _timer.cancel();
    super.dispose();
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

  Future<void> _fetchGroups() async {
    if (globalUtil.userName == null) {
      return;
    }

    try {
      List<GroupInfoModel> groupInfoModels = await getGroups(
        globalUtil.userName!,
      );
      final newGroups = groupInfoModels.map((model) {
        final avatarName = model.groupAvatar; // 默认头像，可根据实际情况修改
        final groupId = model.groupId.toString();
        String avatarURL = globalUtil.getImageURL(groupId, avatarName);
        final previousAvatar = previousAvatars[groupId] ?? '';
        if (avatarURL != previousAvatar && avatarURL.isNotEmpty) {
          previousAvatars[groupId] = avatarURL;
        }
        return GroupChat(
          groupId: groupId,
          name: model.groupName,
          avatar: avatarURL,
          previousAvatar: previousAvatar,
        );
      }).toList();

      setState(() {
        _groupChats = newGroups;
        _filterGroupChats(_searchController.text);
      });
    } catch (e) {
      print('获取群聊列表失败: $e');
    }
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
                                color: Colors.grey[200],
                              ),
                              child: ClipOval(
                                child: Stack(
                                  children: [
                                    if (groupChat.previousAvatar.isNotEmpty)
                                      Positioned.fill(
                                        child: Image.network(
                                          groupChat.previousAvatar,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    Positioned.fill(
                                      child: Image.network(
                                        _addTimestamp(groupChat.avatar),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return Icon(
                                                Icons.group,
                                                color: Colors.grey,
                                              );
                                            },
                                      ),
                                    ),
                                  ],
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
