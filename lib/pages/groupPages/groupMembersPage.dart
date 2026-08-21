import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/cache/app_image_cache.dart';

import '../../model/groupMemberModel.dart';
import '../../api/getGroupMemberAPI.dart';
import '../../utils/gloabl.dart';

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
  List<GroupMemberModel> _groupMembers = [];
  List<GroupMemberModel> _filteredMembers = [];
  late Timer _timer;
  final globalUtil = GlobalUtil();
  // 静态缓存已经加载成功的头像 URL，避免重复加载
  static Map<String, String> _avatarCache = {};

  @override
  void initState() {
    super.initState();
    print('初始化群成员页面');
    // 直接设置 _filteredMembers，避免 _filterMembers 方法可能的问题
    _filteredMembers = _groupMembers;
    print('初始化默认数据完成，成员数: ${_filteredMembers.length}');
    // 初始化时获取一次成员列表
    _fetchGroupMembers();
    // 设置定时器，每秒获取一次成员列表
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _fetchGroupMembers();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchGroupMembers() async {
    try {
      int groupIdInt = int.parse(widget.groupId);

      List<GroupMemberModel> members = await getGroupMembers(groupIdInt);

      // 确保成员列表不为空
      if (members.isEmpty) {
        print('获取到的成员列表为空，使用模拟数据');
      }
      setState(() {
        _groupMembers = members;
        // 直接设置 _filteredMembers，避免 _filterMembers 方法可能的问题
        _filteredMembers = members;
        print('更新状态成功，_filteredMembers 数量: ${_filteredMembers.length}');
      });
    } catch (e) {
      print('获取群成员失败: $e');
    }
  }

  void _filterMembers(String query) {
    print('开始过滤成员，查询条件: "$query"，总成员数: ${_groupMembers.length}');
    if (query.isEmpty) {
      _filteredMembers = _groupMembers;
    } else {
      _filteredMembers = _groupMembers.where((member) {
        return member.groupNickName.toLowerCase().contains(query.toLowerCase());
      }).toList();
      // 确保过滤后的列表不为空
      if (_filteredMembers.isEmpty) {
        print('过滤结果为空，使用原始列表');
        _filteredMembers = _groupMembers;
      }
    }
    print('过滤完成，结果数: ${_filteredMembers.length}');
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('群聊成员'),
          backgroundColor: Colors.white,
          elevation: 1,
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
                onChanged: (query) {
                  _filterMembers(query);
                  setState(() {});
                },
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
                  print('构建列表项，索引: $index');
                  final member = _filteredMembers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[200],
                      radius: 20,
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: _getAvatarUrl(member),
                          cacheKey: AppImageCache.cacheKey(
                            _getAvatarUrl(member),
                          ),
                          fit: BoxFit.cover,
                          width: 40,
                          height: 40,
                          errorWidget: (context, error, stackTrace) {
                            print('加载头像失败: $error');
                            return Text(member.groupNickName.substring(0, 1));
                          },
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        _buildRoleBadge(member.role),
                        SizedBox(width: 8),
                        Text(
                          member.groupNickName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text('ID: ${member.userId}'),
                  );
                },
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('构建页面失败: $e');
      // 显示错误页面
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('群聊成员'),
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: Center(child: Text('页面加载失败，请重试')),
      );
    }
  }

  // 获取头像 URL，使用缓存避免重复加载
  String _getAvatarUrl(GroupMemberModel member) {
    try {
      String userId = member.userId;
      // 使用 member.avatar 作为头像文件名
      String avatarName = member.avatar.isNotEmpty ? member.avatar : 'head.jpg';
      // 生成新的头像 URL
      String newAvatarUrl = globalUtil.getImageURL(userId, avatarName);

      // 检查缓存中是否已有该用户的头像，并且 URL 是否相同
      if (_avatarCache.containsKey(userId)) {
        String cachedUrl = _avatarCache[userId]!;
        if (cachedUrl == newAvatarUrl) {
          // URL 相同，使用缓存的头像 URL
          return cachedUrl;
        } else {
          // URL 不同，使用新的头像 URL 并更新缓存
          _avatarCache[userId] = newAvatarUrl;
          return newAvatarUrl;
        }
      } else {
        // 缓存中没有，使用新的头像 URL 并加入缓存
        _avatarCache[userId] = newAvatarUrl;
        return newAvatarUrl;
      }
    } catch (e) {
      print('获取头像 URL 失败: $e');
      return 'https://via.placeholder.com/40';
    }
  }

  // 构建角色标记
  Widget _buildRoleBadge(int role) {
    String text;
    Color color;

    switch (role) {
      case 2:
        text = '群主';
        color = Colors.orange;
        break;
      case 1:
        text = '管理员';
        color = Colors.green;
        break;
      case 0:
        text = '成员';
        color = Colors.grey;
        break;
      default:
        text = '成员';
        color = Colors.grey;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
