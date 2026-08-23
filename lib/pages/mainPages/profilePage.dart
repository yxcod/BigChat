import 'package:flutter/material.dart';
import '../../utils/gloabl.dart';
import '../../api/getInfoAPI.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/cache/app_image_cache.dart';

class ProfilePage extends StatefulWidget {
  ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

// 我的页面
class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  String signature = "有个性,不签名";
  String nickName = "默认昵称";
  Map<String, dynamic> _profileEditInfo = {};
  String _currentAvatarUrl = '';

  @override
  bool get wantKeepAlive => true;

  Future<void> _fetchProfileInfo() async {
    try {
      final userInfo = await getUserInfoApi(GlobalUtil().userName ?? "");
      if (mounted) {
        nickName = userInfo.nickName ?? "默认昵称";
        signature = userInfo.signature ?? "有个性,不签名";
        _profileEditInfo["nickName"] = nickName;
        _profileEditInfo["signature"] = signature;
        // 更新头像 URL，使用缓存机制
        String avatarName = userInfo.avatar ?? "head.jpg";
        String newAvatarUrl = GlobalUtil().getImageURL(
          GlobalUtil().userName ?? "",
          avatarName,
        );

        // 只有当 URL 发生变化时才更新
        if (newAvatarUrl != _currentAvatarUrl) {
          _currentAvatarUrl = newAvatarUrl;
        }

        setState(() {});
      }
    } catch (e) {
      debugPrint('获取个性信息失败: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchProfileInfo();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      // appBar: AppBar(
      //   title: Text('我的', style: TextStyle(color: Colors.black)),
      //   backgroundColor: Colors.white,
      //   elevation: 1,
      //   actions: [
      //     IconButton(
      //       icon: Icon(Icons.settings, color: Colors.black),
      //       onPressed: () {},
      //     ),
      //   ],
      // ),
      body: ListView(
        children: [
          // 个人信息卡片
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[200],
                        child: ClipOval(
                          child: CachedNetworkImage(
                            cacheManager: AppImageCache.manager,
                            imageUrl: _currentAvatarUrl.isNotEmpty
                                ? _currentAvatarUrl
                                : GlobalUtil().getImageURL(
                                    GlobalUtil().userName ?? "",
                                    "head.jpg",
                                  ),
                            cacheKey: AppImageCache.cacheKey(
                              _currentAvatarUrl.isNotEmpty
                                  ? _currentAvatarUrl
                                  : GlobalUtil().getImageURL(
                                      GlobalUtil().userName ?? "",
                                      "head.jpg",
                                    ),
                            ),
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            progressIndicatorBuilder:
                                (context, url, progress) => Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    value: progress.progress,
                                  ),
                                ),
                            errorWidget: (context, url, error) {
                              debugPrint('头像加载失败：$error');
                              return Icon(
                                Icons.person,
                                color: Colors.grey[400],
                                size: 40,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nickName,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          GlobalUtil().userName ?? "123",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    Spacer(),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10),

          // 功能列表
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.edit, color: Colors.green),
                  title: Text('资料编辑'),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onTap: () async {
                    // 导航到编辑页面并等待返回
                    await Navigator.pushNamed(
                      context,
                      '/ProfileEditPage',
                      arguments: _profileEditInfo,
                    );
                    // 返回后重新获取个人信息
                    _fetchProfileInfo();
                  },
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFE5E5E5)),
                ListTile(
                  leading: Icon(Icons.album, color: Colors.green),
                  title: Text('我的空间'),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onTap: () => Navigator.pushNamed(context, '/myMoments'),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFE5E5E5)),
                // ListTile(
                //   leading: Icon(Icons.card_giftcard, color: Colors.green),
                //   title: Text('卡包'),
                //   trailing: Icon(
                //     Icons.arrow_forward_ios,
                //     color: Colors.grey,
                //     size: 16,
                //   ),
                //   onTap: () {},
                // ),
                ListTile(
                  leading: Icon(Icons.settings, color: Colors.green),
                  title: Text('设置'),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onTap: () => Navigator.pushNamed(context, '/settings'),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFE5E5E5)),
                ListTile(
                  leading: Icon(Icons.help_outline, color: Colors.green),
                  title: Text('其它'),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey,
                    size: 16,
                  ),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
