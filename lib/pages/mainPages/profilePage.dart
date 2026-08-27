import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../api/getInfoAPI.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';
import '../../core/cache/app_image_cache.dart';
import '../../core/media/video_media.dart';
import '../../features/moments/data/moments_repository.dart';
import '../../features/moments/data/server_moments_repository.dart';
import '../../features/moments/domain/moment.dart';
import '../../features/nearby/presentation/nearby_merchants_page.dart';
import '../../model/userInfoModel.dart';
import '../../utils/gloabl.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    this.profileLoader = getUserInfoApi,
    this.momentsRepository,
    this.initialProfile,
    this.initialMoments = const [],
    this.autoLoad = true,
  });

  final Future<UserInfoModel> Function(String userName) profileLoader;
  final MomentsRepository? momentsRepository;
  final UserInfoModel? initialProfile;
  final List<Moment> initialMoments;
  final bool autoLoad;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with AutomaticKeepAliveClientMixin {
  late final MomentsRepository _momentsRepository;
  String signature = '有个性，不签名';
  String nickName = '默认昵称';
  int gender = 0;
  String region = '';
  Map<String, dynamic> _profileEditInfo = {};
  String _currentAvatarUrl = '';
  List<Moment> _moments = const [];
  bool _isLoadingMoments = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _momentsRepository =
        widget.momentsRepository ?? ServerMomentsRepository.instance;
    _moments = List<Moment>.from(widget.initialMoments);
    _applyProfile(widget.initialProfile ?? GlobalUtil().userInfoModel);
    if (widget.autoLoad) {
      _fetchProfileInfo();
      _fetchMoments();
    }
  }

  void _applyProfile(UserInfoModel userInfo) {
    nickName = userInfo.nickName?.trim().isNotEmpty == true
        ? userInfo.nickName!.trim()
        : '默认昵称';
    signature = userInfo.signature?.trim().isNotEmpty == true
        ? userInfo.signature!.trim()
        : '有个性，不签名';
    gender = userInfo.gender;
    region = userInfo.region.trim();
    _profileEditInfo = {
      'nickName': nickName,
      'signature': signature,
      'gender': gender,
      'region': region,
    };

    final userName = GlobalUtil().userName ?? userInfo.userName ?? '';
    final avatarName = userInfo.avatar ?? '';
    if (userName.isEmpty || avatarName.isEmpty) {
      _currentAvatarUrl = '';
      return;
    }
    try {
      _currentAvatarUrl = GlobalUtil().getImageURL(userName, avatarName);
    } catch (_) {
      _currentAvatarUrl = '';
    }
  }

  Future<void> _fetchProfileInfo() async {
    final userName = GlobalUtil().userName ?? '';
    if (userName.isEmpty) return;
    try {
      final userInfo = await widget.profileLoader(userName);
      if (!mounted) return;
      GlobalUtil().userInfoModel = userInfo;
      setState(() => _applyProfile(userInfo));
    } catch (error) {
      debugPrint('获取个性信息失败: $error');
    }
  }

  Future<void> _fetchMoments() async {
    final userName = GlobalUtil().userName ?? '';
    if (userName.isEmpty) return;
    if (mounted) setState(() => _isLoadingMoments = true);
    try {
      final moments = await _momentsRepository.fetchOwnMoments(userName);
      if (!mounted) return;
      setState(() {
        _moments = moments;
        _isLoadingMoments = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingMoments = false);
      debugPrint('加载个人动态预览失败: $error');
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchProfileInfo(), _fetchMoments()]);
  }

  Future<void> _editProfile() async {
    await Navigator.pushNamed(
      context,
      '/ProfileEditPage',
      arguments: _profileEditInfo,
    );
    if (!mounted) return;
    await _fetchProfileInfo();
  }

  Future<void> _openMySpace() async {
    await Navigator.pushNamed(context, '/myMoments');
    if (!mounted) return;
    await _fetchMoments();
  }

  List<String> get _previewImages => _moments
      .expand((moment) => moment.mediaPaths)
      .where((path) => path.trim().isNotEmpty && !isVideoPath(path))
      .take(3)
      .toList(growable: false);

  int get _totalLikes =>
      _moments.fold<int>(0, (total, moment) => total + moment.likeCount);

  String get _account =>
      GlobalUtil().userName ?? widget.initialProfile?.userName ?? '';

  String get _profileMeta {
    final values = <String>[];
    if (gender != 0) values.add(userGenderLabel(gender));
    if (region.isNotEmpty) values.add(region);
    return values.isEmpty ? '资料待完善' : values.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: context.appSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '我的',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _buildProfileCard(),
            const SizedBox(height: 16),
            _buildMomentsCard(),
            const SizedBox(height: 16),
            _buildNearbyCard(),
            const SizedBox(height: 16),
            _buildSettingsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      key: const ValueKey('profile_summary_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        nickName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      key: const ValueKey('edit_profile_button'),
                      onPressed: _editProfile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text(
                        '编辑资料',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '账号：${_account.isEmpty ? '未设置' : _account}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _profileMeta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  signature,
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
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final fallback = Container(
      color: const Color(0xFFEAF8F0),
      alignment: Alignment.center,
      child: Text(
        nickName.isEmpty ? '我' : nickName.substring(0, 1),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: 74,
        height: 74,
        child: _currentAvatarUrl.isEmpty
            ? fallback
            : CachedNetworkImage(
                cacheManager: AppImageCache.manager,
                imageUrl: _currentAvatarUrl,
                cacheKey: AppImageCache.cacheKey(_currentAvatarUrl),
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }

  Widget _buildMomentsCard() {
    return Material(
      key: const ValueKey('my_space_card'),
      color: context.appSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: _openMySpace,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFFEAF8F0),
                        borderRadius: BorderRadius.all(Radius.circular(11)),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '我的空间',
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '记录生活中的每个瞬间',
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFA3A6AB),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _buildMomentPreview(),
              const SizedBox(height: 12),
              Text(
                '动态 ${_moments.length} · 获赞 $_totalLikes',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMomentPreview() {
    if (_isLoadingMoments && _moments.isEmpty) {
      return const SizedBox(
        height: 88,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }
    final images = _previewImages;
    if (images.isEmpty) {
      return Container(
        height: 82,
        decoration: BoxDecoration(
          color: context.appSearchBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_outlined, color: Color(0xFFB3B6BA), size: 22),
            SizedBox(width: 8),
            Text(
              '还没有带图片的动态',
              style: TextStyle(color: context.appTextSecondary, fontSize: 12.5),
            ),
          ],
        ),
      );
    }
    if (images.length == 1) {
      return SizedBox(
        height: 92,
        child: SizedBox(width: 110, child: _buildPreviewImage(images.first)),
      );
    }
    return SizedBox(
      height: 92,
      child: Row(
        children: List.generate(images.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == images.length - 1 ? 0 : 7,
              ),
              child: _buildPreviewImage(images[index]),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPreviewImage(String path) {
    final fallback = ColoredBox(
      color: context.appSearchBackground,
      child: Icon(Icons.broken_image_outlined, color: context.appTextSecondary),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: path.startsWith('http://') || path.startsWith('https://')
          ? CachedNetworkImage(
              cacheManager: AppImageCache.manager,
              imageUrl: path,
              cacheKey: AppImageCache.cacheKey(path),
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => fallback,
            )
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      key: const ValueKey('profile_settings_card'),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildMenuRow(
            icon: Icons.settings_outlined,
            title: '设置',
            subtitle: '偏好设置与更多',
            onTap: () => Navigator.pushNamed(context, '/settings'),
          ),
          Divider(
            height: 1,
            indent: 66,
            endIndent: 14,
            color: context.appDivider,
          ),
          _buildMenuRow(
            icon: Icons.more_horiz_rounded,
            title: '其它',
            subtitle: '关于全信',
            onTap: () => Navigator.pushNamed(context, '/about'),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyCard() {
    return Container(
      key: const ValueKey('profile_nearby_card'),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildMenuRow(
        icon: Icons.near_me_outlined,
        title: '附近',
        subtitle: '发现身边的商家与地点',
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NearbyMerchantsPage())),
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.appSurface,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 66,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F0),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA3A6AB),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
