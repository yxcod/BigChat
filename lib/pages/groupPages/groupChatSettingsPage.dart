import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'groupMembersPage.dart';
import '../../model/groupMemberModel.dart';
import '../../model/groupInfoModel.dart';
import '../../api/getGroupMemberAPI.dart';
import '../../api/getGroupInfoAPI.dart';
import '../../utils/Gloabl.dart';

class GroupChatSettingsPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<GroupMemberModel> groupMembers;

  const GroupChatSettingsPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    this.groupMembers = const [],
  }) : super(key: key);

  @override
  _GroupChatSettingsPageState createState() => _GroupChatSettingsPageState();
}

class _GroupChatSettingsPageState extends State<GroupChatSettingsPage> {
  String _groupName = '';
  String _groupAnnouncement = '未设置';
  String _groupAvatar = 'https://via.placeholder.com/60';
  List<Map<String, dynamic>> _members = [];
  late Timer _timer;
  final globalUtil = GlobalUtil();
  // 静态缓存已经加载成功的头像 URL，避免重复加载
  static Map<String, String> _avatarCache = {};
  // 静态缓存已经加载成功的群头像 URL，避免重复加载
  static Map<String, String> _groupAvatarCache = {};
  // 当前用户是否为群主
  bool _isOwner = false;
  // 当前用户的本群昵称
  String _myNickname = '';
  // 群的创建时间
  String _groupCreatedAt = '';
  // 群公告
  String _groupDescription = '';

  Future<void> _pickGroupAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _groupAvatar = image.path;
      });

      // 这里可以添加上传头像的逻辑
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text('群头像已更新'),
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
  }

  void _inviteMembers() async {
    final result = await Navigator.pushNamed(context, '/selectContactsPage');
    if (result != null && result is List<dynamic>) {
      // 处理返回的选择结果
      List<dynamic> selectedFriends = result;
      // 这里可以添加邀请好友进群的逻辑
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('提示'),
            content: Text('已邀请 ${selectedFriends.length} 位好友'),
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
  }

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    // 初始化时获取一次成员列表
    _fetchGroupMembers();
    // 初始化时获取一次群信息
    _fetchGroupInfo();
    // 设置定时器，每秒获取一次成员列表
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      _fetchGroupMembers();
    });
  }

  // 获取群信息
  Future<void> _fetchGroupInfo() async {
    try {
      // 获取当前用户的所有群信息
      List<GroupInfoModel> groups = await getGroups(globalUtil.userName ?? '');
      // 找到当前群
      for (var group in groups) {
        if (group.groupId.toString() == widget.groupId) {
          // 将时间戳转换为可读的日期时间格式（只显示年月日）
          DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(
            group.createdAt,
          );
          String formattedDate =
              '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
          setState(() {
            _groupCreatedAt = formattedDate;
            _groupDescription = group.description;
          });
          break;
        }
      }
    } catch (e) {
      print('获取群信息失败: $e');
    }
  }

  @override
  void dispose() {
    // 清理定时器
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchGroupMembers() async {
    try {
      int groupIdInt = int.parse(widget.groupId);
      List<GroupMemberModel> members = await getGroupMembers(groupIdInt);

      // 遍历群成员列表，找到当前用户并设置相关信息
      try {
        // 根据用户要求，userId 就是 userName
        String? currentUserId = globalUtil.userName;
        bool foundUser = false;
        String? userGroupNickName = '';
        bool isOwner = false;

        for (var member in members) {
          print(
            '群成员: userId=${member.userId}, groupNickName=${member.groupNickName}, role=${member.role},createTime=${member.joinTime}',
          );
          if (currentUserId != null && member.userId == currentUserId) {
            // 获取当前用户的本群昵称
            userGroupNickName = member.groupNickName;
            // 检查是否为群主
            if (member.role == 2) {
              isOwner = true;
            } else {
              isOwner = false;
            }
            foundUser = true;
            break;
          }
        }

        if (!foundUser) {
          print('未找到当前用户在群成员列表中');
        }

        // 在 setState 中更新 UI 相关的变量
        setState(() {
          _myNickname = userGroupNickName ?? '';
          _isOwner = isOwner;
        });

        print('更新后的 _myNickname: $_myNickname');
      } catch (e) {
        print('获取当前用户 ID 失败: $e');
      }

      // 将 GroupMemberModel 转换为 Map<String, dynamic> 类型的 _members 列表
      setState(() {
        _members = members.map((member) {
          String avatarUrl;
          try {
            // 检查缓存中是否已有该用户的头像
            if (_avatarCache.containsKey(member.userId)) {
              // 使用缓存的头像 URL
              avatarUrl = _avatarCache[member.userId]!;
            } else {
              // 尝试获取实际头像
              avatarUrl = globalUtil.getImageURL(member.userId, 'head.jpg');
              // 将获取到的头像 URL 存入缓存
              _avatarCache[member.userId] = avatarUrl;
            }
          } catch (e) {
            // 如果获取失败（例如 token 为 null），使用默认头像
            avatarUrl = 'https://via.placeholder.com/40';
          }
          return {
            'id': member.userId,
            'name': member.groupNickName,
            'avatar': avatarUrl,
          };
        }).toList();
      });
    } catch (e) {
      print('获取群聊成员列表失败: $e');
    }
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

  void _viewAllMembers() {
    // 导航到群成员页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMembersPage(
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      ),
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

  // 获取群头像 URL，使用缓存避免重复加载
  String _getGroupAvatarUrl() {
    if (_groupAvatarCache.containsKey(widget.groupId)) {
      return _groupAvatarCache[widget.groupId]!;
    } else {
      try {
        String url = globalUtil.getImageURL(widget.groupId, 'head.jpg');
        _groupAvatarCache[widget.groupId] = url;
        return url;
      } catch (e) {
        return 'https://via.placeholder.com/60';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                  margin: EdgeInsets.only(right: 12.0),
                  child: CachedNetworkImage(
                    width: 60.0,
                    height: 60.0,
                    imageUrl: _getGroupAvatarUrl(),
                    imageBuilder: (context, imageProvider) => Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    placeholder: (context, url) => Container(
                      width: 60.0,
                      height: 60.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 60.0,
                      height: 60.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[200],
                      ),
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
                        _groupDescription.isNotEmpty
                            ? _groupDescription
                            : '未设置群公告',
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
                  height: 70.0,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount:
                        _members.length +
                        (_isOwner ? 2 : 1), // +1 用于邀请按钮, 只有群主才显示移除按钮
                    itemBuilder: (context, index) {
                      if (index < _members.length) {
                        final member = _members[index];
                        return Container(
                          margin: EdgeInsets.only(right: 16.0),
                          child: Column(
                            children: [
                              CachedNetworkImage(
                                width: 40.0,
                                height: 40.0,
                                imageUrl: _avatarCache.containsKey(member['id'])
                                    ? _avatarCache[member['id']]!
                                    : member['avatar'],
                                imageBuilder: (context, imageProvider) =>
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                placeholder: (context, url) => Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image:
                                        _avatarCache.containsKey(member['id'])
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              _avatarCache[member['id']]!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: Colors.grey[200],
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image:
                                        _avatarCache.containsKey(member['id'])
                                        ? DecorationImage(
                                            image: NetworkImage(
                                              _avatarCache[member['id']]!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: Colors.grey[200],
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
                          ),
                        );
                      } else if (index == _members.length) {
                        // 邀请按钮
                        return Container(
                          margin: EdgeInsets.only(right: 16.0),
                          child: GestureDetector(
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
                                  child: Icon(
                                    Icons.add,
                                    color: Colors.grey[500],
                                  ),
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
                          ),
                        );
                      } else if (_isOwner && index == _members.length + 1) {
                        // 移除按钮，只有群主才显示
                        return Container(
                          margin: EdgeInsets.only(right: 16.0),
                          child: GestureDetector(
                            onTap: () {
                              // 实现移除成员功能
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: Text('移除成员'),
                                    content: Text('请选择要移除的成员'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          // 这里可以添加移除成员的逻辑
                                        },
                                        child: Text('确定'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 40.0,
                                  height: 40.0,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey[200],
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                SizedBox(height: 4.0),
                                Text(
                                  '移除',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      } else {
                        // 其他情况返回空容器
                        return Container();
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

                // 创建时间
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
                        '创建时间',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        _groupCreatedAt.isNotEmpty ? _groupCreatedAt : '加载中...',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // 群头像设置
                GestureDetector(
                  onTap: _pickGroupAvatar,
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
                          '群头像',
                          style: TextStyle(
                            fontSize: 14.0,
                            color: Colors.grey[800],
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 40.0,
                              height: 40.0,
                              margin: EdgeInsets.only(right: 8.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: _groupAvatar.startsWith('http')
                                      ? NetworkImage(_groupAvatar)
                                      : FileImage(File(_groupAvatar))
                                            as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Text(
                              '修改',
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

                // 群号
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
                        '群号',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        widget.groupId,
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
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
                        '我在本群的昵称',
                        style: TextStyle(
                          fontSize: 14.0,
                          color: Colors.grey[800],
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _myNickname.isEmpty ? '未设置' : _myNickname,
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
