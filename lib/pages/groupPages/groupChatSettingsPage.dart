import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'groupMembersPage.dart';
import '../../model/groupMemberModel.dart';
import '../../model/groupInfoModel.dart';
import '../../api/getGroupMemberAPI.dart';
import '../../api/getGroupInfoAPI.dart';
import '../../api/delete_chat_history_api.dart';
import '../../utils/gloabl.dart';
import '../../utils/http.dart';
import '../../core/cache/app_image_cache.dart';
import '../../core/config/refresh_intervals.dart';
import '../../features/groups/domain/group_role_policy.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../features/groups/presentation/group_route_registry.dart';
import '../../features/chat/domain/chat_realtime_event.dart';
import '../../utils/WebSocketManager.dart';
import '../../features/group_resources/presentation/group_resources_page.dart';
import '../../features/group_resources/presentation/group_resource_list_page.dart';
import '../../features/group_resources/domain/group_resource.dart';
import '../../app/theme/app_theme_context.dart';
import '../../shared/pages/app_text_editor_page.dart';
import '../../features/groups/application/group_notification_settings_service.dart';

class GroupChatSettingsPage extends StatefulWidget {
  final String groupId;
  final String groupName;
  final List<GroupMemberModel> groupMembers;
  final bool loadRemoteData;

  const GroupChatSettingsPage({
    Key? key,
    required this.groupId,
    required this.groupName,
    this.groupMembers = const [],
    this.loadRemoteData = true,
  }) : super(key: key);

  @override
  _GroupChatSettingsPageState createState() => _GroupChatSettingsPageState();
}

class _GroupChatSettingsPageState extends State<GroupChatSettingsPage> {
  String _groupName = '';
  String _groupAnnouncement = '未设置';
  String _groupAvatar = 'https://via.placeholder.com/60';
  List<Map<String, dynamic>> _members = [];
  // 存储所有定时器，便于在需要时停止
  Timer? _timer;
  Timer? _groupInfoTimer;
  final globalUtil = GlobalUtil();
  // 静态缓存已经加载成功的头像 URL，避免重复加载
  static Map<String, String> _avatarCache = {};

  int _myRole = GroupRolePolicy.member;
  bool get _canManageMembers => GroupRolePolicy.canManageMembers(_myRole);
  WebSocketMessageSubscription? _groupEventSubscription;
  // 当前用户的本群昵称
  String _myNickname = '';
  // 群的创建时间
  String _groupCreatedAt = '';
  // 群公告
  String _groupDescription = '';
  // 群信息模型，用于存储完整的群信息
  GroupInfoModel? _groupInfoModel;
  // 上传取消令牌
  CancelToken? _uploadCancelToken;
  final GroupNotificationSettingsService _groupNotificationSettings =
      GroupNotificationSettingsService.instance;
  bool _groupMuted = false;

  Future<void> _pickGroupAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (image != null) {
      // 创建取消令牌
      _uploadCancelToken = CancelToken();

      try {
        if (await image.length() > 5 * 1024 * 1024) {
          throw Exception('图片压缩后仍超过5MB，请选择较小的图片');
        }

        // 生成带时间戳的图片名
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String imageName = 'head_$timestamp.jpg';

        // 创建 HttpUtil 实例
        final httpUtil = HttpUtil();

        // 调用 uploadImage 函数上传图片，使用群 ID 作为 userName
        bool success = await httpUtil.uploadImageFile(
          imageName,
          image.path,
          userName: widget.groupId, // 使用群 ID 作为 userName
          cancelToken: _uploadCancelToken,
        );

        if (mounted) {
          if (success) {
            // 更新群信息中的头像字段
            try {
              // 获取当前用户的 userName
              String? currentUserId = globalUtil.userName;
              if (currentUserId == null) {
                throw Exception('当前用户未登录');
              }

              // 将 groupId 转换为 int 类型
              int groupIdInt = int.parse(widget.groupId);

              // 获取当前群的信息，用于保持其他字段不变
              int maxMembers = _groupInfoModel?.maxMembers ?? 200;
              int isActive = _groupInfoModel?.isActive ?? 1;

              // 准备群公告内容，确保不是 '未设置'
              String description = _groupDescription == '未设置'
                  ? ''
                  : _groupDescription;

              // 调用 API 更新群信息，传入新的头像名
              int code = await updateGroupInfo(
                currentUserId,
                groupIdInt,
                _groupName, // 保持群名称不变
                description, // 保持群公告不变
                maxMembers,
                isActive,
                imageName, // 新的头像名
              );

              if (code == 100) {
                // 更新成功，重新获取群信息
                await _fetchGroupInfo();

                // 更新 _groupAvatar 为新的头像 URL
                try {
                  String url = globalUtil.getImageURL(
                    widget.groupId,
                    imageName,
                  );
                  setState(() {
                    _groupAvatar = url;
                  });
                } catch (e) {
                  print('更新群头像 URL 失败: $e');
                  setState(() {
                    _groupAvatar = image.path;
                  });
                }

                // 显示成功提示
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
              } else {
                throw Exception('更新群信息失败，错误码: $code');
              }
            } catch (e) {
              print('更新群头像失败: $e');
              // 显示错误提示
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: Text('提示'),
                    content: Text('更新群头像失败: $e'),
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
          } else {
            // 显示失败提示
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text('提示'),
                  content: Text('群头像上传失败'),
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
      } catch (e) {
        if (mounted) {
          // 显示错误提示
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text('提示'),
                content: Text('上传失败: $e'),
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
      } finally {
        // 重置取消令牌
        _uploadCancelToken = null;
      }
    }
  }

  void _inviteMembers() async {
    await Navigator.pushNamed(
      context,
      '/selectContactsPage',
      arguments: {'groupId': widget.groupId},
    );
    if (mounted) {
      await _fetchGroupMembers();
      await _fetchGroupInfo();
    }
  }

  @override
  void initState() {
    super.initState();
    GroupRouteRegistry.enter(int.tryParse(widget.groupId) ?? 0);
    _groupEventSubscription = WebSocketManager().addMessageListener(
      _handleGroupEvent,
    );
    _groupName = widget.groupName;
    _groupAnnouncement = '未设置';
    _groupDescription = '未设置';
    unawaited(_loadGroupNotificationSetting());
    // 初始化时不需要手动设置群头像 URL，会在 _fetchGroupInfo 中自动设置
    // 群头像 URL 会根据 GroupInfoModel 中的 groupAvatar 字段动态生成
    // 只有当 groupAvatar 字段发生变化时，才会重新从网络上获取头像
    // 初始化时获取一次成员列表
    if (widget.loadRemoteData) {
      _fetchGroupMembers();
      // 初始化时获取一次群信息
      _fetchGroupInfo();
      // 操作完成后会主动刷新，定时器只作为低频兜底。
      _timer = Timer.periodic(
        RefreshIntervals.groupFallback,
        (timer) => _fetchGroupMembers(),
      );
      _groupInfoTimer = Timer.periodic(
        RefreshIntervals.groupFallback,
        (timer) => _fetchGroupInfo(),
      );
    }
  }

  Future<void> _loadGroupNotificationSetting() async {
    await _groupNotificationSettings.ensureCurrentUserLoaded();
    if (!mounted) return;
    setState(() {
      _groupMuted = _groupNotificationSettings.isMuted(
        int.tryParse(widget.groupId) ?? 0,
      );
    });
  }

  Future<void> _setGroupMuted(bool value) async {
    final previous = _groupMuted;
    setState(() => _groupMuted = value);
    try {
      await _groupNotificationSettings.setMuted(
        int.tryParse(widget.groupId) ?? 0,
        value,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _groupMuted = previous);
      _showSnackBar('免打扰设置保存失败，请重试');
    }
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
            _groupAnnouncement = group.description.isEmpty
                ? '未设置'
                : group.description;
            _groupName = group.groupName; // 更新群名称
            _groupInfoModel = group; // 存储完整的群信息
            // 更新群头像 URL 为 groupAvatar 字段对应的 URL
            try {
              String avatarName = group.groupAvatar.isNotEmpty
                  ? group.groupAvatar
                  : 'head.jpg';
              String url = globalUtil.getImageURL(widget.groupId, avatarName);
              _groupAvatar = url;
            } catch (e) {
              print('更新群头像 URL 失败: $e');
            }
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
    GroupRouteRegistry.leave(int.tryParse(widget.groupId) ?? 0);
    _groupEventSubscription?.cancel();
    // 清理所有定时器
    _timer?.cancel();
    _groupInfoTimer?.cancel();
    // 取消上传操作
    if (_uploadCancelToken != null && !_uploadCancelToken!.isCancelled) {
      _uploadCancelToken!.cancel('页面已关闭');
    }
    super.dispose();
  }

  void _handleGroupEvent(dynamic rawMessage) {
    if (rawMessage is! Map<String, dynamic>) return;
    final event = ChatRealtimeEvent.parse(rawMessage);
    if (event.groupId != int.tryParse(widget.groupId)) return;
    if (event.type == ChatRealtimeEventType.groupMemberRoleUpdated ||
        event.type == ChatRealtimeEventType.groupMemberMuteUpdated) {
      unawaited(_fetchGroupMembers());
    }
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
        int myRole = GroupRolePolicy.member;

        for (var member in members) {
          print(
            '群成员: userId=${member.userId}, groupNickName=${member.groupNickName}, role=${member.role},createTime=${member.joinTime}',
          );
          if (currentUserId != null && member.userId == currentUserId) {
            // 获取当前用户的本群昵称
            userGroupNickName = member.groupNickName;
            myRole = member.role;
            foundUser = true;
            break;
          }
        }

        if (!foundUser) {
          print('未找到当前用户在群成员列表中');
          // 停止所有定时器，防止重复触发弹窗
          _timer?.cancel();
          _groupInfoTimer?.cancel();
          // 用户不在群成员列表中，说明已被移除出群聊
          if (mounted) {
            // 导航到主界面并传递被移除群聊的信号，同时清除导航栈
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/mainWidget',
              (route) => false, // 清除所有路由，使mainWidget成为根页面
              arguments: {'isRemovedFromGroup': true},
            );
          }
          return;
        }

        // 在 setState 中更新 UI 相关的变量
        setState(() {
          _myNickname = userGroupNickName ?? '';
          _myRole = myRole;
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
            // 使用 member.avatar 作为头像文件名
            String avatarName = member.avatar.isNotEmpty
                ? member.avatar
                : 'head.jpg';
            // 生成新的头像 URL
            String newAvatarUrl = globalUtil.getImageURL(
              member.userId,
              avatarName,
            );

            // 检查缓存中是否已有该用户的头像，并且 URL 是否相同
            if (_avatarCache.containsKey(member.userId)) {
              String cachedUrl = _avatarCache[member.userId]!;
              if (cachedUrl == newAvatarUrl) {
                // URL 相同，使用缓存的头像 URL
                avatarUrl = cachedUrl;
              } else {
                // URL 不同，使用新的头像 URL 并更新缓存
                avatarUrl = newAvatarUrl;
                _avatarCache[member.userId] = newAvatarUrl;
              }
            } else {
              // 缓存中没有，使用新的头像 URL 并加入缓存
              avatarUrl = newAvatarUrl;
              _avatarCache[member.userId] = newAvatarUrl;
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
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AppTextEditorPage(
          title: '编辑群聊名称',
          initialValue: _groupName,
          hintText: '请输入群聊名称',
          maxLength: 30,
          allowEmpty: false,
          emptyMessage: '群聊名称不能为空',
          fieldKey: const Key('group_name_editor'),
          saveButtonKey: const Key('group_name_save_button'),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        print('开始更新群名称: $result');
        print('群名称长度: ${result.length}');
        print('群名称编码: ${result.runes}');
        // 获取当前用户的 userName
        String? currentUserId = globalUtil.userName;
        if (currentUserId == null) {
          throw Exception('当前用户未登录');
        }

        // 将 groupId 转换为 int 类型
        int groupIdInt = int.parse(widget.groupId);

        // 获取当前群的信息，用于保持 maxMembers 和 isActive 不变
        int maxMembers = _groupInfoModel?.maxMembers ?? 200;
        int isActive = _groupInfoModel?.isActive ?? 1;

        // 准备群公告内容，确保不是 '未设置'
        String description = _groupDescription == '未设置'
            ? ''
            : _groupDescription;
        print('群公告 (发送到服务器): $description');

        // 调用 API 更新群信息
        print('准备调用 updateGroupInfo');
        int code = await updateGroupInfo(
          currentUserId,
          groupIdInt,
          result.trim(), // 新的群名称，去除前后空格
          description, // 保持群公告不变
          maxMembers,
          isActive,
          null, // 不更新头像字段
        );
        print('updateGroupInfo 返回码: $code');

        if (code == 100) {
          setState(() {
            _groupName = result.trim();
          });

          // 显示成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('群名称更新成功'),
              duration: const Duration(seconds: 2),
            ),
          );
          print('群名称更新成功');
        } else {
          throw Exception('更新失败，错误码: $code');
        }
      } catch (e) {
        print('更新群名称失败: $e');

        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('群名称更新失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _editGroupAnnouncement() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AppTextEditorPage(
          title: '编辑群介绍',
          initialValue: _groupAnnouncement == '未设置' ? '' : _groupAnnouncement,
          hintText: '请输入群介绍',
          maxLength: 20,
          maxLines: 4,
          fieldKey: const Key('group_description_editor'),
          saveButtonKey: const Key('group_description_save_button'),
        ),
      ),
    );

    if (result != null) {
      try {
        // 获取当前用户的 userName
        String? currentUserId = globalUtil.userName;
        if (currentUserId == null) {
          throw Exception('当前用户未登录');
        }

        // 将 groupId 转换为 int 类型
        int groupIdInt = int.parse(widget.groupId);

        // 获取当前群的信息，用于保持 maxMembers 和 isActive 不变
        int maxMembers = _groupInfoModel?.maxMembers ?? 200;
        int isActive = _groupInfoModel?.isActive ?? 1;

        // 准备新的群公告内容
        String newDescription = result.isEmpty ? '未设置' : result;

        // 准备发送到服务器的群公告内容，确保不是 '未设置'
        String descriptionForServer = result.isEmpty ? '' : result;

        int code = await updateGroupInfo(
          currentUserId,
          groupIdInt,
          _groupName, // 保持群名称不变
          descriptionForServer, // 新的群公告
          maxMembers,
          isActive,
          null, // 不更新头像字段
        );

        if (code == 100) {
          setState(() {
            _groupAnnouncement = newDescription;
            _groupDescription = newDescription; // 同时更新 _groupDescription
          });

          // 显示成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('群公告更新成功'),
              duration: const Duration(seconds: 2),
            ),
          );
          print('群公告更新成功');
        } else {
          throw Exception('更新失败，错误码: $code');
        }
      } catch (e) {
        print('更新群公告失败: $e');

        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('群公告更新失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
              onPressed: () async {
                Navigator.pop(context);

                try {
                  // 获取当前用户的 userName
                  String? currentUserId = globalUtil.userName;
                  if (currentUserId == null) {
                    throw Exception('当前用户未登录');
                  }

                  // 将 groupId 转换为 int 类型
                  int groupIdInt = int.parse(widget.groupId);

                  // 调用 minuGroup 函数，将用户自身从群聊中移除
                  int code = await minuGroup(groupIdInt, [currentUserId]);

                  if (code == 100) {
                    // 主动退群后立即清理本地群状态，并离开该群相关的全部页面。
                    // 仅 pop 设置页会重新露出仍在栈中的群聊页，也会让“我的群聊”
                    // 暂时保留旧数据，直到下一次定时刷新。
                    globalUtil.clearGroupMembers(groupIdInt);
                    await globalUtil.deleteChatRecords(
                      GlobalUtil.groupConversationKey(groupIdInt),
                    );
                    if (!context.mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/mainWidget', (route) => false);
                  } else {
                    throw Exception('退出群聊失败，错误码: $code');
                  }
                } catch (e) {
                  print('退出群聊失败: $e');
                  // 显示错误提示
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('提示'),
                        content: Text('退出群聊失败: $e'),
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
              },
              child: Text('确定', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteChatHistoryDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('删除群聊记录'),
        content: Text('将永久删除该群在服务器和本机保存的全部聊天记录，所有群成员均无法再查看。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final currentUserName = globalUtil.userName ?? '';
              if (currentUserName.isEmpty) {
                _showSnackBar('当前用户未登录');
                return;
              }
              try {
                final response = await deleteGroupChatHistoryApi(
                  userName: currentUserName,
                  groupId: int.parse(widget.groupId),
                );
                if (response['code'] != 100) {
                  throw Exception(response['msg'] ?? '服务器删除失败');
                }
                await globalUtil.deleteChatRecords(
                  GlobalUtil.groupConversationKey(widget.groupId),
                );
                if (!mounted) return;
                _showSnackBar('群聊记录已删除');
                Navigator.pop(context, true);
              } catch (error) {
                debugPrint('删除群聊记录失败: $error');
                if (mounted) _showSnackBar('删除群聊记录失败，请重试');
              }
            },
            child: Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _openGroupResources() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupResourcesPage(
          groupId: int.parse(widget.groupId),
          groupName: _groupName,
        ),
      ),
    );
  }

  Widget _buildResourceShortcut({
    required IconData icon,
    required Color color,
    required String label,
    required GroupResourceType type,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GroupResourceListPage(
            groupId: int.parse(widget.groupId),
            groupName: _groupName,
            type: type,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: EdgeInsets.all(6),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 29),
            ),
            SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  void _editMyNickname() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AppTextEditorPage(
          title: '设置本群昵称',
          initialValue: _myNickname,
          hintText: '请输入我在本群的昵称',
          maxLength: 30,
          fieldKey: const Key('group_nickname_editor'),
          saveButtonKey: const Key('group_nickname_save_button'),
        ),
      ),
    );

    if (result != null) {
      try {
        // 获取当前用户的 userName（userId）
        String? currentUserId = globalUtil.userName;
        if (currentUserId == null) {
          throw Exception('当前用户未登录');
        }

        // 将 groupId 转换为 int 类型
        int groupIdInt = int.parse(widget.groupId);

        // 调用 API 更新信息
        int code = await updateGroupMemberNickname(
          currentUserId,
          groupIdInt,
          result.trim(),
        );

        if (code == 100) {
          setState(() {
            _myNickname = result.trim();
          });

          // 显示成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('昵称更新成功'),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          throw Exception('更新失败，错误码: $code');
        }
      } catch (e) {
        print('更新群昵称失败: $e');

        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('昵称更新失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        title: Text('群聊设置'),
        backgroundColor: context.appSurface,
        elevation: 1,
        leading: const AppBackButton(),
      ),
      body: ListView(
        children: [
          // 群聊基本信息
          Container(
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 1.0),
              ),
              color: context.appSurface,
            ),
            child: Row(
              children: [
                Container(
                  margin: EdgeInsets.only(right: 12.0),
                  child: CachedNetworkImage(
                    cacheManager: AppImageCache.manager,
                    width: 60.0,
                    height: 60.0,
                    imageUrl: _groupAvatar,
                    cacheKey: AppImageCache.cacheKey(_groupAvatar),
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
              ],
            ),
          ),

          Container(
            key: const ValueKey('group_notification_settings_card'),
            margin: const EdgeInsets.only(top: 12),
            color: context.appSurface,
            child: SwitchTheme(
              data: SwitchThemeData(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: SwitchListTile.adaptive(
                key: const ValueKey('group_mute_switch'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                title: const Text(
                  '群消息免打扰',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                value: _groupMuted,
                onChanged: _setGroupMuted,
              ),
            ),
          ),

          // 群聊成员
          Container(
            margin: EdgeInsets.only(top: 12.0),
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(color: context.appSurface),
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
                    itemCount: _members.length + (_canManageMembers ? 2 : 1),
                    itemBuilder: (context, index) {
                      if (index < _members.length) {
                        final member = _members[index];
                        return Container(
                          margin: EdgeInsets.only(right: 16.0),
                          child: Column(
                            children: [
                              CachedNetworkImage(
                                cacheManager: AppImageCache.manager,
                                width: 40.0,
                                height: 40.0,
                                imageUrl: _avatarCache.containsKey(member['id'])
                                    ? _avatarCache[member['id']]!
                                    : member['avatar'],
                                cacheKey: AppImageCache.cacheKey(
                                  _avatarCache.containsKey(member['id'])
                                      ? _avatarCache[member['id']]!
                                      : member['avatar'],
                                ),
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
                                            image: AppImageCache.provider(
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
                                            image: AppImageCache.provider(
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
                      } else if (_canManageMembers &&
                          index == _members.length + 1) {
                        // 群主和管理员均可进入移除成员页面，后端会按目标角色再次校验。
                        return Container(
                          margin: EdgeInsets.only(right: 16.0),
                          child: GestureDetector(
                            onTap: () {
                              // 导航到选择要移除的成员页面
                              Navigator.pushNamed(
                                context,
                                '/selectGroupMembersToRemovePage',
                                arguments: {'groupId': widget.groupId},
                              ).then((result) {
                                if (result != null) {
                                  // 重新获取群成员列表，确保更新
                                  _fetchGroupMembers();
                                }
                              });
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
            decoration: BoxDecoration(color: context.appSurface),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _openGroupResources,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '群资源',
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    ],
                  ),
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    _buildResourceShortcut(
                      icon: Icons.folder_rounded,
                      color: Color(0xFFFFB41F),
                      label: '群文件',
                      type: GroupResourceType.file,
                    ),
                    SizedBox(width: 42),
                    _buildResourceShortcut(
                      icon: Icons.photo_library_rounded,
                      color: Color(0xFF2B9DF4),
                      label: '群相册',
                      type: GroupResourceType.photo,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 群聊信息
          Container(
            margin: EdgeInsets.only(top: 12.0),
            padding: EdgeInsets.all(16.0),
            decoration: BoxDecoration(color: context.appSurface),
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
                                      ? AppImageCache.provider(_groupAvatar)
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
                          '群介绍',
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
                GestureDetector(
                  onTap: _editMyNickname,
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
                ),
              ],
            ),
          ),

          if (_canManageMembers)
            Container(
              margin: EdgeInsets.only(top: 24.0),
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: OutlinedButton(
                onPressed: _showDeleteChatHistoryDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red),
                  minimumSize: Size(double.infinity, 48.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text('删除群聊记录', style: TextStyle(fontSize: 16.0)),
              ),
            ),

          // 退出群聊按钮
          Container(
            margin: EdgeInsets.only(top: 12.0, bottom: 32.0),
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
