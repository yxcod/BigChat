import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/gloabl.dart';
import '../../api/getGroupInfoAPI.dart';
import '../../model/groupInfoModel.dart';

class GroupChat {
  final int groupId;
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
      groupId: model.groupId,
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
  // 静态缓存已经加载成功的头像 URL，避免重复加载
  static final Map<String, String> _avatarCache = {};
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
        final groupId = model.groupId; // 保持整数类型
        String avatarURL = _getAvatarUrl(
          groupId.toString(),
          avatarName,
        ); // 获取头像URL时转换为字符串
        final groupIdStr = groupId.toString(); // 用于缓存键
        final previousAvatar = previousAvatars[groupIdStr] ?? '';
        if (avatarURL != previousAvatar && avatarURL.isNotEmpty) {
          previousAvatars[groupIdStr] = avatarURL;
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

  // 获取头像 URL，使用缓存避免重复加载
  String _getAvatarUrl(String groupId, String avatarName) {
    try {
      final cacheKey = '$groupId-$avatarName';
      if (_avatarCache.containsKey(cacheKey)) {
        return _avatarCache[cacheKey]!;
      } else {
        String url = globalUtil.getImageURL(groupId, avatarName);

        _avatarCache[cacheKey] = url;
        return url;
      }
    } catch (e) {
      print('获取头像 URL 异常: $e');
      return '';
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
                        //groupChat.groupId
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
                                child: CachedNetworkImage(
                                  imageUrl: groupChat.avatar,
                                  fit: BoxFit.cover,
                                  width: 50,
                                  height: 50,
                                  placeholder: (context, url) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: Icon(
                                        Icons.group,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                  errorWidget: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: Icon(
                                        Icons.group,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
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
