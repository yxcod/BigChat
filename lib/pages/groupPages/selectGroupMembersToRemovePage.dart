import 'package:flutter/material.dart';
import '../../model/groupMemberModel.dart';
import '../../api/getGroupMemberAPI.dart';
import '../../utils/Gloabl.dart';

class SelectGroupMembersToRemovePage extends StatefulWidget {
  final String groupId;

  const SelectGroupMembersToRemovePage({Key? key, required this.groupId})
    : super(key: key);

  @override
  _SelectGroupMembersToRemovePageState createState() =>
      _SelectGroupMembersToRemovePageState();
}

class _SelectGroupMembersToRemovePageState
    extends State<SelectGroupMembersToRemovePage> {
  TextEditingController _searchController = TextEditingController();
  ScrollController _scrollController = ScrollController();
  List<GroupMemberModel> _allMembers = [];
  List<GroupMemberModel> _filteredMembers = [];
  List<GroupMemberModel> _selectedMembers = [];
  List<String> _alphabetList = [];
  Map<String, List<GroupMemberModel>> _membersByAlphabet = {};
  Map<String, GlobalKey> _alphabetKeys = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _fetchGroupMembers();
    _loadMembers();
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

      List<GroupMemberModel> members = await getGroupMembers(groupIdInt);

      // 检查当前用户是否在群成员列表中
      String? currentUserName = GlobalUtil().userName;
      if (currentUserName != null &&
          !members.any((member) => member.userId == currentUserName)) {
        // 用户不在群成员列表中，说明已被移除出群聊
        if (mounted) {
          // 显示弹窗提示
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('提示'),
              content: Text('您已被移除出群聊'),
              actions: [
                TextButton(
                  onPressed: () {
                    // 退出所有群聊相关界面，返回最上级
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text('确定'),
                ),
              ],
            ),
          );
        }
        return;
      }

      setState(() {
        _allMembers = members;
      });
    } catch (e) {
      print('获取群成员列表失败: $e');
      _allMembers = [];
    }
  }

  void _loadMembers() {
    // 获取当前用户的用户名
    String? currentUserName = GlobalUtil().userName;

    // 过滤出不是当前用户的群成员
    List<GroupMemberModel> filteredMembers = _allMembers.where((member) {
      return currentUserName == null || member.userId != currentUserName;
    }).toList();

    // 按字母分组
    _membersByAlphabet = {};
    _alphabetList = [];
    _alphabetKeys = {};

    for (var member in filteredMembers) {
      String firstChar = member.groupNickName.isNotEmpty
          ? member.groupNickName[0].toUpperCase()
          : '#';
      if (!RegExp(r'[A-Z]').hasMatch(firstChar)) {
        firstChar = '#';
      }

      if (!_membersByAlphabet.containsKey(firstChar)) {
        _membersByAlphabet[firstChar] = [];
        _alphabetList.add(firstChar);
        _alphabetKeys[firstChar] = GlobalKey();
      }
      _membersByAlphabet[firstChar]!.add(member);
    }

    // 排序字母列表
    _alphabetList.sort((a, b) {
      if (a == '#') return 1;
      if (b == '#') return -1;
      return a.compareTo(b);
    });

    _filteredMembers = filteredMembers;
  }

  void _filterMembers(String query) {
    if (query.isEmpty) {
      // 恢复原始的按字母分组
      _membersByAlphabet = {};
      _alphabetList = [];
      _alphabetKeys = {};

      // 获取当前用户的用户名
      String? currentUserName = GlobalUtil().userName;

      // 过滤出不是当前用户的群成员
      List<GroupMemberModel> filteredMembers = _allMembers.where((member) {
        return currentUserName == null || member.userId != currentUserName;
      }).toList();

      for (var member in filteredMembers) {
        String firstChar = member.groupNickName.isNotEmpty
            ? member.groupNickName[0].toUpperCase()
            : '#';
        if (!RegExp(r'[A-Z]').hasMatch(firstChar)) {
          firstChar = '#';
        }

        if (!_membersByAlphabet.containsKey(firstChar)) {
          _membersByAlphabet[firstChar] = [];
          _alphabetList.add(firstChar);
          _alphabetKeys[firstChar] = GlobalKey();
        }
        _membersByAlphabet[firstChar]!.add(member);
      }

      // 排序字母列表
      _alphabetList.sort((a, b) {
        if (a == '#') return 1;
        if (b == '#') return -1;
        return a.compareTo(b);
      });
    } else {
      // 根据搜索结果重新分组，只显示不是当前用户的群成员
      String? currentUserName = GlobalUtil().userName;
      _filteredMembers = _allMembers.where((member) {
        return (currentUserName == null || member.userId != currentUserName) &&
            member.groupNickName.toLowerCase().contains(query.toLowerCase());
      }).toList();

      _membersByAlphabet = {};
      _alphabetList = [];
      _alphabetKeys = {};

      for (var member in _filteredMembers) {
        String firstChar = member.groupNickName.isNotEmpty
            ? member.groupNickName[0].toUpperCase()
            : '#';
        if (!RegExp(r'[A-Z]').hasMatch(firstChar)) {
          firstChar = '#';
        }

        if (!_membersByAlphabet.containsKey(firstChar)) {
          _membersByAlphabet[firstChar] = [];
          _alphabetList.add(firstChar);
          _alphabetKeys[firstChar] = GlobalKey();
        }
        _membersByAlphabet[firstChar]!.add(member);
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

  void _toggleMemberSelection(GroupMemberModel member) {
    setState(() {
      if (_selectedMembers.contains(member)) {
        _selectedMembers.remove(member);
      } else {
        _selectedMembers.add(member);
      }
    });
  }

  void _confirmSelection() async {
    try {
      // 从选中的成员中提取 userId 列表
      List<String> selectedUserIds = _selectedMembers
          .map((member) => member.userId)
          .toList();

      // 检查是否有选中的成员
      if (selectedUserIds.isEmpty) {
        throw Exception('请至少选择一个成员');
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

      // 调用 removeGroupMember 接口
      int code = await minuGroup(groupIdInt, selectedUserIds);

      if (code == 100) {
        // 检查页面是否仍然可见
        if (mounted) {
          // 显示成功提示
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('移除群成员成功')));

          // 更新群成员列表，确保下次打开页面时能正确显示
          setState(() {
            // 从所有成员列表中移除已选择的成员
            _allMembers.removeWhere(
              (member) => _selectedMembers.contains(member),
            );

            // 重新加载成员列表，确保正确过滤
            _loadMembers();

            // 清空选中的成员列表
            _selectedMembers.clear();
          });

          // 返回上一页
          Navigator.pop(context, _selectedMembers);
        }
      } else {
        throw Exception('移除群成员失败，错误码: $code');
      }
    } catch (e) {
      print('移除群成员失败: $e');

      // 检查页面是否仍然可见
      if (mounted) {
        // 显示错误提示
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('移除群成员失败: $e')));
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
        title: Text('选择要移除的成员'),
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
                    onChanged: _filterMembers,
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

                // 成员列表
                Expanded(
                  child: Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        itemCount: _alphabetList.length,
                        itemBuilder: (context, index) {
                          String alphabet = _alphabetList[index];
                          List<GroupMemberModel> members =
                              _membersByAlphabet[alphabet]!;

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

                              // 成员列表
                              Column(
                                children: members.map((member) {
                                  return Container(
                                    color: Colors.white,
                                    child: ListTile(
                                      leading: Checkbox(
                                        value: _selectedMembers.contains(
                                          member,
                                        ),
                                        onChanged: (value) {
                                          _toggleMemberSelection(member);
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
                                                image: NetworkImage(
                                                  GlobalUtil().getImageURL(
                                                    member.userId,
                                                    'head.jpg',
                                                  ),
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
                                                  member.groupNickName,
                                                  style: TextStyle(
                                                    fontSize: 16.0,
                                                  ),
                                                ),
                                                Text(
                                                  'ID: ${member.userId}',
                                                  style: TextStyle(
                                                    fontSize: 12.0,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        _toggleMemberSelection(member);
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
                        onPressed: _selectedMembers.isNotEmpty
                            ? _confirmSelection
                            : null,
                        child: Text(
                          '完成',
                          style: TextStyle(
                            color: _selectedMembers.isNotEmpty
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
