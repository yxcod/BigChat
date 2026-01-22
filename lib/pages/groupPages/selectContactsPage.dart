import 'package:flutter/material.dart';
import '../../model/friendInfoModel.dart';

class SelectContactsPage extends StatefulWidget {
  const SelectContactsPage({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  void _loadFriends() {
    // 模拟加载好友列表
    _allFriends = [
      FriendInfoModel(
        userName: '1',
        nickName: 'A.程',
        remarks: '15970401550',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '2',
        nickName: 'A0上门电脑维修',
        remarks: '13800138000',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '3',
        nickName: 'A-李锐',
        remarks: '13900139000',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '4',
        nickName: 'A0租租鸭数码免押租赁',
        remarks: '13700137000',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '5',
        nickName: 'AA余安妮',
        remarks: '13600136000',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '6',
        nickName: 'AAA文体照相',
        remarks: '13500135000',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '7',
        nickName: 'AA南京【车务】',
        remarks: '13338619686',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '8',
        nickName: 'A卖萌的小公主',
        remarks: '13200132000',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '9',
        nickName: '奥凸曼汽车维修',
        remarks: '13100131000',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '10',
        nickName: 'A中国电信吴俊',
        remarks: '13000130000',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '11',
        nickName: 'B-张三',
        remarks: '13400134000',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '12',
        nickName: 'C-李四',
        remarks: '13500135001',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
      FriendInfoModel(
        userName: '13',
        nickName: 'D-王五',
        remarks: '13600136001',
        avatar: 'https://via.placeholder.com/60',
        signature: '',
        isOnline: true,
      ),
    ];

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
    } else {
      // 根据搜索结果重新分组
      _filteredFriends = _allFriends.where((friend) {
        return (friend.nickName?.toLowerCase().contains(query.toLowerCase()) ??
                false) ||
            (friend.remarks?.contains(query) ?? false);
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

  void _confirmSelection() {
    Navigator.pop(context, _selectedFriends);
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
      body: Column(
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
                                  value: _selectedFriends.contains(friend),
                                  onChanged: (value) {
                                    _toggleFriendSelection(friend);
                                  },
                                ),
                                title: Row(
                                  children: [
                                    Container(
                                      width: 40.0,
                                      height: 40.0,
                                      margin: EdgeInsets.only(right: 12.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: NetworkImage(
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
                                            style: TextStyle(fontSize: 16.0),
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
                  onPressed: _confirmSelection,
                  child: Text('完成', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
