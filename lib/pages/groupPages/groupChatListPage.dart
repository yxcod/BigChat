import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/cache/app_image_cache.dart';
import '../../core/config/refresh_intervals.dart';
import '../../utils/gloabl.dart';
import '../../api/getGroupInfoAPI.dart';
import '../../model/groupInfoModel.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../shared/widgets/app_search_field.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';
import '../../features/groups/data/group_data_cache.dart';

class GroupChat {
  final int groupId;
  final String name;
  final String avatar;
  final String previousAvatar;
  final String creatorId;
  final String description;

  GroupChat({
    required this.groupId,
    required this.name,
    required this.avatar,
    required this.previousAvatar,
    this.creatorId = '',
    this.description = '',
  });

  factory GroupChat.fromGroupInfoModel(GroupInfoModel model) {
    return GroupChat(
      groupId: model.groupId,
      name: model.groupName,
      avatar: model.groupAvatar, // 默认头像，可根据实际情况修改
      previousAvatar: '',
      creatorId: model.creatorId,
      description: model.description,
    );
  }
}

class GroupChatListPage extends StatefulWidget {
  const GroupChatListPage({
    super.key,
    this.initialGroups = const [],
    this.autoRefresh = true,
    this.currentUserName,
    this.groupDataCache,
  });

  final List<GroupChat> initialGroups;
  final bool autoRefresh;
  final String? currentUserName;
  final GroupDataCache? groupDataCache;

  @override
  _GroupChatListPageState createState() => _GroupChatListPageState();
}

class _GroupChatListPageState extends State<GroupChatListPage> {
  final GlobalUtil globalUtil = GlobalUtil();
  List<GroupChat> _groupChats = [];
  final Map<String, String> previousAvatars = {};
  final TextEditingController _searchController = TextEditingController();
  List<GroupChat> _filteredGroupChats = [];
  Timer? _timer;
  // 静态缓存已经加载成功的头像 URL，避免重复加载
  static final Map<String, String> _avatarCache = {};
  late final GroupDataCache _groupDataCache =
      widget.groupDataCache ?? GroupDataCache();
  @override
  void initState() {
    super.initState();
    _groupChats = widget.initialGroups.isNotEmpty
        ? List<GroupChat>.from(widget.initialGroups)
        : _mapGroups(
            _groupDataCache.loadGroups(
              widget.currentUserName ?? globalUtil.userName ?? '',
            ),
          );
    _filteredGroupChats = List<GroupChat>.from(_groupChats);
    if (widget.autoRefresh) {
      _fetchGroups();
      _timer = Timer.periodic(
        RefreshIntervals.groupFallback,
        (timer) => _fetchGroups(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _filterGroupChats(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGroupChats = _groupChats;
      } else {
        final keyword = query.toLowerCase();
        _filteredGroupChats = _groupChats.where((group) {
          return group.name.toLowerCase().contains(keyword) ||
              group.description.toLowerCase().contains(keyword);
        }).toList();
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
      final newGroups = _mapGroups(groupInfoModels);

      if (!mounted) return;
      _groupChats = newGroups;
      _filterGroupChats(_searchController.text);
    } catch (e) {
      debugPrint('获取群聊列表失败: $e');
    }
  }

  List<GroupChat> _mapGroups(Iterable<GroupInfoModel> groupInfoModels) {
    return groupInfoModels.map((model) {
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
        creatorId: model.creatorId,
        description: model.description,
      );
    }).toList();
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
      debugPrint('获取头像 URL 异常: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          '我的群聊',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: context.appSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              tooltip: '创建群聊',
              onPressed: _openGroupCreator,
              icon: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF34373C)),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: context.appTextPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: context.appSurface,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: AppSearchField(
              controller: _searchController,
              query: _searchController.text,
              hintText: '搜索群名称或简介',
              onChanged: _filterGroupChats,
              height: 44,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _fetchGroups,
              child: _buildGroupList(),
            ),
          ),
        ],
      ),
    );
  }

  String? get _currentUserName => widget.currentUserName ?? globalUtil.userName;

  List<GroupChat> get _managedGroups => _filteredGroupChats
      .where((group) => group.creatorId == _currentUserName)
      .toList();

  List<GroupChat> get _joinedGroups => _filteredGroupChats
      .where((group) => group.creatorId != _currentUserName)
      .toList();

  void _openGroupCreator() {
    Navigator.pushNamed(context, '/groupCreatePage');
  }

  void _openGroup(GroupChat group) {
    Navigator.pushNamed(
      context,
      '/groupChatDialog',
      arguments: {'groupId': group.groupId, 'groupName': group.name},
    );
  }

  Widget _buildGroupList() {
    final searching = _searchController.text.trim().isNotEmpty;
    if (_filteredGroupChats.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        children: [
          if (!searching) _buildSummaryCard(),
          SizedBox(height: searching ? 250 : 220),
          Column(
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 50,
                color: Color(0xFFD1D4D8),
              ),
              const SizedBox(height: 12),
              Text(
                searching ? '没有找到匹配的群聊' : '暂时还没有群聊',
                style: TextStyle(color: context.appTextSecondary, fontSize: 14),
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        if (!searching) ...[_buildSummaryCard(), const SizedBox(height: 24)],
        if (_managedGroups.isNotEmpty) ...[
          _buildGroupSection(
            title: '我管理的',
            groups: _managedGroups,
            showOwnerBadge: true,
          ),
          const SizedBox(height: 24),
        ],
        if (_joinedGroups.isNotEmpty)
          _buildGroupSection(title: '我加入的', groups: _joinedGroups),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Material(
      key: const ValueKey('group_summary_card'),
      color: context.appSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _openGroupCreator,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.groups_2_outlined,
                  color: AppColors.primary,
                  size: 25,
                ),
                const SizedBox(width: 12),
                Text(
                  '共 ${_groupChats.length} 个群聊',
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  '创建群聊',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 21,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSection({
    required String title,
    required List<GroupChat> groups,
    bool showOwnerBadge = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: title,
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: '  ${groups.length}',
                style: TextStyle(color: context.appTextSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(groups.length, (index) {
              return Column(
                children: [
                  _buildGroupRow(groups[index], showOwnerBadge: showOwnerBadge),
                  if (index < groups.length - 1)
                    Divider(
                      height: 1,
                      indent: 80,
                      endIndent: 14,
                      color: context.appDivider,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupRow(GroupChat group, {required bool showOwnerBadge}) {
    return Material(
      color: context.appSurface,
      child: InkWell(
        onTap: () => _openGroup(group),
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _buildGroupAvatar(group),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        group.description.trim().isEmpty
                            ? '暂无群简介'
                            : group.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showOwnerBadge) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF8F0),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: const Text(
                      '群主',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA4A7AC),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(GroupChat group) {
    final fallback = Container(
      color: const Color(0xFFEAF8F0),
      alignment: Alignment.center,
      child: const Icon(
        Icons.groups_rounded,
        color: AppColors.primary,
        size: 26,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 52,
        child: group.avatar.trim().isEmpty
            ? fallback
            : CachedNetworkImage(
                cacheManager: AppImageCache.manager,
                imageUrl: group.avatar,
                cacheKey: AppImageCache.cacheKey(group.avatar),
                fit: BoxFit.cover,
                placeholder: (context, url) => fallback,
                errorWidget: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}
