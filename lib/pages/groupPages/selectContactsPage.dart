import 'package:flutter/material.dart';
import '../../model/friendInfoModel.dart';
import '../../api/getGroupMemberAPI.dart';
import '../../utils/gloabl.dart';
import '../../core/cache/app_image_cache.dart';

class SelectContactsPage extends StatefulWidget {
  final String groupId;

  const SelectContactsPage({Key? key, required this.groupId}) : super(key: key);

  @override
  _SelectContactsPageState createState() => _SelectContactsPageState();
}

class _SelectContactsPageState extends State<SelectContactsPage> {
  TextEditingController _searchController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  List<FriendInfoModel> _allFriends = [];
  List<FriendInfoModel> _filteredFriends = [];
  List<FriendInfoModel> _selectedFriends = [];
  List<String> _alphabetList = [];
  Map<String, List<FriendInfoModel>> _friendsByAlphabet = {};
  Map<String, GlobalKey> _alphabetKeys = {};
  List<String> _groupMemberUserIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 先清空群成员列表，确保每次重新获取最新数据
    _groupMemberUserIds = [];
    await _fetchGroupMembers();
    _loadFriends();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchGroupMembers() async {
    try {
      // 转换 groupId 为 int 类型，处理可能的格式异常
      int? groupIdInt = int.tryParse(widget.groupId);
      if (groupIdInt == null) {
        throw Exception('无效的群 ID 格式');
      }

      List<dynamic> members = await getGroupMembers(groupIdInt);
      setState(() {
        _groupMemberUserIds = members
            .map((member) => (member.userId ?? "").toString())
            .toList();
      });
    } catch (e) {
      print('获取群成员列表失败: $e');
      _groupMemberUserIds = [];
    }
  }

  void _loadFriends() {
    // 从 GlobalUtil 获取真实的好友列表
    List<FriendInfoModel> allFriends =
        GlobalUtil().userInfoModel.friendListData ?? [];

    // 过滤出不在群中的好友
    _allFriends = allFriends.where((friend) {
      return !_groupMemberUserIds.contains(friend.userName ?? "");
    }).toList();

    // 按字母分组
    _friendsByAlphabet = {};
    _alphabetList = [];
    _alphabetKeys = {};

    for (var friend in _allFriends) {
      String firstChar = friend.nickName?.isNotEmpty ?? false
          ? friend.nickName![0].toUpperCase()
          : '#';
      if (!RegExp(r'[A-Z]').hasMatch(firstChar)) {
        firstChar = '#';
      }

      if (!_friendsByAlphabet.containsKey(firstChar)) {
        _friendsByAlphabet[firstChar] = [];
        _alphabetList.add(firstChar);
        _alphabetKeys[firstChar] = GlobalKey();
      }
      _friendsByAlphabet[firstChar]!.add(friend);
    }

    // 排序字母列表
    _alphabetList.sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });

    _filteredFriends = _allFriends;
  }

  void _filterFriends(String query) {
    if (query.isEmpty) {
      // 恢复原始的按字母分组
      _friendsByAlphabet = {};
      _alphabetList = [];
      _alphabetKeys = {};

      for (var friend in _allFriends) {
        // 确保只显示不在群中的好友
        if (!_groupMemberUserIds.contains(friend.userName ?? "")) {
          String firstChar = friend.nickName?.isNotEmpty ?? false
              ? friend.nickName![0].toUpperCase()
              : '#';
          if (!RegExp(r'[A-Z]').hasMatch(firstChar)) {
            firstChar = '#';
          }

          if (!_friendsByAlphabet.containsKey(firstChar)) {
            _friendsByAlphabet[firstChar] = [];
            _alphabetList.add(firstChar);
            _alphabetKeys[firstChar] = GlobalKey();
          }
          _friendsByAlphabet[firstChar]!.add(friend);
        }
      }

      // 排序字母列表
      _alphabetList.sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });
    } else {
      // 根据搜索结果重新分组，只显示不在群中的好友
      _filteredFriends = _allFriends.where((friend) {
        return !_groupMemberUserIds.contains(friend.userName ?? "") &&
            ((friend.nickName?.toLowerCase().contains(query.toLowerCase()) ??
                    false) ||
                (friend.remarks?.contains(query) ?? false));
      }).toList();

      _friendsByAlphabet = {};
      _alphabetList = [];
      _alphabetKeys = {};

      for (var friend in _filteredFriends) {
        String firstChar = friend.nickName?.isNotEmpty ?? false
            ? friend.nickName![0].toUpperCase()
            : '#';
        if (!RegExp(r'[A-Z]').hasMatch(firstChar)) {
          firstChar = '#';
        }

        if (!_friendsByAlphabet.containsKey(firstChar)) {
          _friendsByAlphabet[firstChar] = [];
          _alphabetList.add(firstChar);
          _alphabetKeys[firstChar] = GlobalKey();
        }
        _friendsByAlphabet[firstChar]!.add(friend);
      }

      // 排序字母列表
      _alphabetList.sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });
    }
    setState(() {});
  }

  void _toggleFriendSelection(FriendInfoModel friend) {
    setState(() {
      if (_selectedFriends.contains(friend)) {
        _selectedFriends.remove(friend);
      } else {
        _selectedFriends.add(friend);
      }
    });
  }

  void _confirmSelection() async {
    try {
      // 从选中的好友中提取 userName 列表，并处理可空值
      List<String> selectedUserNames = _selectedFriends
          .map((friend) => friend.userName ?? "")
          .toList();

      // 过滤掉空字符串，确保只传递有效的用户名
      selectedUserNames = selectedUserNames
          .where((userName) => userName.isNotEmpty)
          .toList();

      // 检查是否有选中的好友
      if (selectedUserNames.isEmpty) {
        throw Exception('请至少选择一个好友');
      }

      // 转换 groupId 为 int 类型，处理可能的格式异常
      int? groupIdInt;
      try {
        groupIdInt = int.tryParse(widget.groupId);
        if (groupIdInt == null) {
          throw Exception('无效的群 ID 格式');
        }
      } catch (e) {
        throw Exception('无效的群 ID 格式: $e');
      }

      // 调用 addGroup 接口
      int code = await addGroup(groupIdInt, selectedUserNames);

      if (code == 100) {
        // 检查页面是否仍然可见
        if (mounted) {
          // 显示成功提示
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('邀请好友进群成功')));

          // 更新群成员列表，确保下次打开页面时能正确过滤
          setState(() {
            // 将新邀请的好友添加到群成员列表中
            for (var friend in _selectedFriends) {
              if (!_groupMemberUserIds.contains(friend.userName ?? "")) {
                _groupMemberUserIds.add(friend.userName ?? "");
              }
            }
          });

          // 等待状态更新完成后，重新加载好友列表
          Future.delayed(Duration(milliseconds: 100), () {
            setState(() {
              // 重新加载好友列表，确保正确过滤
              _loadFriends();

              // 清空选中的好友列表
              _selectedFriends.clear();
            });

            // 返回上一页
            Navigator.pop(context, _selectedFriends);
          });
        }
      } else {
        throw Exception('邀请好友进群失败，错误码: $code');
      }
    } catch (e) {
      print('邀请好友进群失败: $e');

      // 检查页面是否仍然可见
      if (mounted) {
        // 显示错误提示
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('邀请好友进群失败: $e')));
      }
    }
  }

  void _scrollToAlphabet(String alphabet) {
    if (_alphabetKeys.containsKey(alphabet)) {
      final key = _alphabetKeys[alphabet];
      final context = key?.currentContext;
      if (context != null) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final offset = box.localToGlobal(Offset.zero);
          _scrollController.animateTo(
            offset.dy - 100, // 减去状态栏和搜索框的高度
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('选择联系人'),
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索框
                Container(
                  padding: EdgeInsets.all(12.0),
                  color: Colors.white,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterFriends,
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

                // 好友列表
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        itemCount: _alphabetList.length,
                        itemBuilder: (context, index) {
                          String alphabet = _alphabetList[index];
                          List<FriendInfoModel> friends =
                              _friendsByAlphabet[alphabet]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 字母标题
                              Container(
                                key: _alphabetKeys[alphabet],
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                color: Colors.grey[200],
                                child: Text(
                                  alphabet,
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              // 好友列表
                              Column(
                                children: friends.map((friend) {
                                  return Container(
                                    color: Colors.white,
                                    child: ListTile(
                                      leading: Checkbox(
                                        value: _selectedFriends.contains(
                                          friend,
                                        ),
                                        onChanged: (value) {
                                          _toggleFriendSelection(friend);
                                        },
                                      ),
                                      title: Row(
                                        children: [
                                          Container(
                                            width: 40.0,
                                            height: 40.0,
                                            margin: EdgeInsets.only(
                                              right: 12.0,
                                            ),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              image: DecorationImage(
                                                image: AppImageCache.provider(
                                                  friend.avatar ?? '',
                                                ),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  friend.nickName ?? '',
                                                  style: TextStyle(
                                                    fontSize: 16.0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        _toggleFriendSelection(friend);
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        },
                      ),

                      // 字母索引
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 24.0,
                          color: Colors.transparent,
                          child: ListView.builder(
                            itemCount: _alphabetList.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  _scrollToAlphabet(_alphabetList[index]);
                                },
                                child: Container(
                                  height: 20.0,
                                  alignment: Alignment.center,
                                  child: Text(
                                    _alphabetList[index],
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 底部操作栏
                Container(
                  padding: EdgeInsets.all(12.0),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _selectedFriends.isNotEmpty
                            ? _confirmSelection
                            : null,
                        child: Text(
                          '完成',
                          style: TextStyle(
                            color: _selectedFriends.isNotEmpty
                                ? Colors.black
                                : Colors.grey[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
