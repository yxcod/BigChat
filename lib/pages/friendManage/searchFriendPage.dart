import 'package:flutter/material.dart';
import 'addFriendRequestPage.dart';
import '../../api/getInfoAPI.dart';
import '../../utils/gloabl.dart';
import '../../core/cache/app_image_cache.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../model/userInfoModel.dart';
import 'friendDetailPage.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';

class SearchFriendPage extends StatefulWidget {
  const SearchFriendPage({
    super.key,
    this.userLoader = getUserInfoApi,
    this.currentUserLoader = getUserInfoApi,
    this.profileBuilder,
  });

  final Future<UserInfoModel> Function(String userName) userLoader;
  final Future<UserInfoModel> Function(String userName) currentUserLoader;
  final Widget Function(Map<String, dynamic> userData)? profileBuilder;

  @override
  _SearchFriendPageState createState() => _SearchFriendPageState();
}

class _SearchFriendPageState extends State<SearchFriendPage> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  Map<String, dynamic>? _searchResult;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 自动聚焦到输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_phoneFocusNode);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          '添加好友',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: context.appSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 搜索区域
          _buildSearchSection(),

          // 搜索结果区域
          Expanded(child: _buildSearchResultSection()),
        ],
      ),
    );
  }

  // 构建搜索区域
  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: context.appSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      if (!_isLoading) _performSearch();
                    },
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: '请输入账号或手机号',
                      hintStyle: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: context.appTextSecondary,
                        size: 22,
                      ),
                      suffixIcon: _phoneController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除',
                              onPressed: () {
                                _phoneController.clear();
                                setState(() {});
                              },
                              icon: const Icon(
                                Icons.cancel,
                                color: Color(0xFFB2B4B8),
                                size: 19,
                              ),
                            ),
                      filled: true,
                      fillColor: context.appSearchBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                child: TextButton(
                  onPressed: _isLoading ? null : _performSearch,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Text(
                          '搜索',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '可通过账号或手机号查找用户',
            style: TextStyle(color: context.appTextSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  // 构建搜索结果区域
  Widget _buildSearchResultSection() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 14),
            Text('搜索中...', style: TextStyle(color: context.appTextSecondary)),
          ],
        ),
      );
    }

    if (_searchResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 52,
              color: Color(0xFFD1D4D8),
            ),
            SizedBox(height: 14),
            Text(
              '输入账号或手机号搜索好友',
              style: TextStyle(fontSize: 14, color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }

    // 搜索结果不为空时，用户卡片显示在顶部
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          '搜索结果',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildUserCard(),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primary, size: 17),
            SizedBox(width: 7),
            Text(
              '仅会展示对方公开的基本资料',
              style: TextStyle(color: context.appTextSecondary, fontSize: 12.5),
            ),
          ],
        ),
      ],
    );
  }

  // 构建用户卡片 - 紧凑布局，内容对齐上方
  Widget _buildUserCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openUserProfile,
      child: Container(
        key: const Key('search_friend_result_card'),
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 29,
                  backgroundImage:
                      _searchResult!['avatar'] != null &&
                          _searchResult!['avatar'].isNotEmpty
                      ? AppImageCache.provider(_searchResult!['avatar'])
                      : null,
                  backgroundColor: context.appSearchBackground,
                  child:
                      _searchResult!['avatar'] == null ||
                          _searchResult!['avatar'].isEmpty
                      ? Text(
                          _searchResult!['nickname'] != null &&
                                  _searchResult!['nickname'].isNotEmpty
                              ? _searchResult!['nickname'][0]
                              : '?',
                          style: TextStyle(
                            fontSize: 21,
                            color: context.appTextSecondary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _searchResult!['nickname'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '账号：${_searchResult!['phone'] ?? ''}',
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profileMeta,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      if ((_searchResult!['signature'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _searchResult!['signature'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _isAddedFriend
                    ? Container(
                        key: const Key('search_friend_added_status'),
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.appSearchBackground,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Text(
                          '已添加',
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : SizedBox(
                        key: const Key('search_friend_add_button'),
                        height: 34,
                        child: ElevatedButton(
                          onPressed: _navigateToAddFriend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          child: const Text(
                            '添加好友',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 15),
            Divider(height: 1, color: context.appDivider),
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Text(
                    '点击查看公开资料',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9A9DA2),
                    size: 22,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 是否已添加该好友
  bool _isAddedFriend = false;

  String get _profileMeta {
    final region = (_searchResult?['region'] ?? '').toString().trim();
    final genderValue = _searchResult?['gender'];
    final gender = genderValue == 1 || genderValue?.toString() == '1'
        ? '男'
        : genderValue == 2 || genderValue?.toString() == '2'
        ? '女'
        : '';
    final values = [region, gender].where((value) => value.isNotEmpty).toList();
    return values.isEmpty ? '地区未知' : values.join(' · ');
  }

  // 执行搜索
  Future<void> _performSearch() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showSnackBar('请输入手机号', Colors.orange);
      return;
    }

    if (RegExp(r'^\d+$').hasMatch(phone) && phone.length != 11) {
      _showSnackBar('请输入正确的手机号格式', Colors.orange);
      return;
    }

    // 检查输入的手机号是否是自身的userName
    final currentUserName = GlobalUtil().userName;
    if (currentUserName != null && phone == currentUserName) {
      _showSnackBar('无法添加自身为好友', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
      _searchResult = null;
      _isAddedFriend = false;
    });

    try {
      final userInfo = await widget.userLoader(phone);
      final targetUserName = userInfo.userName?.trim() ?? phone;
      final isAddedFriend = await _resolveFriendship(targetUserName);
      if (!mounted) return;

      final avatarName = userInfo.avatar ?? '';
      String avatarUrl = '';
      final globalUtil = GlobalUtil();
      if (globalUtil.token != null && avatarName.isNotEmpty) {
        try {
          avatarUrl = globalUtil.getImageURL(targetUserName, avatarName);
        } catch (error) {
          debugPrint('获取头像URL失败: $error');
        }
      }

      setState(() {
        _isLoading = false;
        _searchResult = {
          'avatar': avatarUrl,
          'nickname': userInfo.nickName ?? '',
          'phone': targetUserName,
          'userName': targetUserName,
          'signature': userInfo.signature ?? '',
          'gender': userInfo.gender,
          'region': userInfo.region,
          'isFriend': isAddedFriend,
        };
        _isAddedFriend = isAddedFriend;
      });
      _showSnackBar('找到用户', Colors.green);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _searchResult = null;
        _isAddedFriend = false;
      });
      _showSnackBar('用户不存在', Colors.red);
      debugPrint('搜索用户失败: $error');
    }
  }

  Future<bool> _resolveFriendship(String targetUserName) async {
    final globalUtil = GlobalUtil();
    if (globalUtil.hasFriend(targetUserName)) return true;

    final currentUserName = globalUtil.userName?.trim() ?? '';
    if (currentUserName.isEmpty) return false;
    try {
      final refreshedUser = await widget.currentUserLoader(currentUserName);
      if (refreshedUser.friendListData != null) {
        globalUtil.userInfoModel = refreshedUser;
      }
    } catch (error) {
      debugPrint('刷新当前好友列表失败，使用本地好友状态: $error');
    }
    return globalUtil.hasFriend(targetUserName);
  }

  // 跳转到添加好友页面
  void _navigateToAddFriend() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddFriendRequestPage(targetUser: _searchResult!),
      ),
    );
  }

  Future<void> _openUserProfile() async {
    final result = _searchResult;
    if (result == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            widget.profileBuilder?.call(Map.of(result)) ??
            FriendDetailPage(friendData: Map.of(result)),
      ),
    );
    if (!mounted) return;
    final targetUserName = result['userName']?.toString() ?? '';
    final latestFriendship = GlobalUtil().hasFriend(targetUserName);
    if (latestFriendship != _isAddedFriend) {
      setState(() {
        _isAddedFriend = latestFriendship;
        _searchResult!['isFriend'] = latestFriendship;
      });
    }
  }

  // 显示提示信息
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}
