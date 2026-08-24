import 'package:flutter/material.dart';
import 'addFriendRequestPage.dart';
import '../../api/getInfoAPI.dart';
import '../../utils/gloabl.dart';
import '../../core/cache/app_image_cache.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../model/userInfoModel.dart';
import 'friendDetailPage.dart';

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
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('搜索好友'),
        backgroundColor: Colors.white,
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
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          // 输入框
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 36, // 减小高度
              child: TextField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '请输入手机号',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                  prefixIcon: Icon(Icons.phone, color: Colors.grey, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(width: 8),

          // 搜索按钮
          SizedBox(
            width: 60, // 减小宽度
            height: 36, // 减小高度
            child: ElevatedButton(
              onPressed: _isLoading ? null : _performSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: EdgeInsets.zero,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('搜索', style: TextStyle(fontSize: 14)),
            ),
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
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('搜索中...'),
          ],
        ),
      );
    }

    if (_searchResult == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '输入手机号搜索好友',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // 搜索结果不为空时，用户卡片显示在顶部
    return Align(alignment: Alignment.topCenter, child: _buildUserCard());
  }

  // 构建用户卡片 - 紧凑布局，内容对齐上方
  Widget _buildUserCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openUserProfile,
      child: Container(
        key: const Key('search_friend_result_card'),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // 内容对齐上方
          children: [
            // 用户头像 - 缩小尺寸
            CircleAvatar(
              radius: 20,
              backgroundImage:
                  _searchResult!['avatar'] != null &&
                      _searchResult!['avatar'].isNotEmpty
                  ? AppImageCache.provider(_searchResult!['avatar'])
                  : null,
              backgroundColor: Colors.grey[200],
              child:
                  _searchResult!['avatar'] == null ||
                      _searchResult!['avatar'].isEmpty
                  ? Text(
                      _searchResult!['nickname'] != null &&
                              _searchResult!['nickname'].isNotEmpty
                          ? _searchResult!['nickname'][0]
                          : '?',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    )
                  : null,
            ),

            SizedBox(width: 10),

            // 用户信息 - 只显示关键信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _searchResult!['nickname'] ?? '',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 1),
                  Text(
                    _searchResult!['phone'] ?? '',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            SizedBox(width: 8),

            // 添加按钮或已添加文本 - 根据好友状态显示
            Padding(
              padding: EdgeInsets.only(top: 2), // 稍微调整位置使其更对齐
              child: _isAddedFriend
                  ? SizedBox(
                      key: const Key('search_friend_added_status'),
                      width: 55,
                      height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '已添加',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      key: const Key('search_friend_add_button'),
                      width: 55,
                      height: 28,
                      child: ElevatedButton(
                        onPressed: () => _navigateToAddFriend(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: EdgeInsets.zero,
                          elevation: 1,
                        ),
                        child: Text('添加', style: TextStyle(fontSize: 11)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 是否已添加该好友
  bool _isAddedFriend = false;

  // 执行搜索
  Future<void> _performSearch() async {
    String phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showSnackBar('请输入手机号', Colors.orange);
      return;
    }

    if (phone.length != 11) {
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
