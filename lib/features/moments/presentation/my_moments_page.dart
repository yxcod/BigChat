import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../core/cache/app_image_cache.dart';
import '../../../core/media/video_media.dart';
import '../../../core/media/chat_media_saver.dart';
import '../../../model/userInfoModel.dart';
import '../../../utils/gloabl.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../shared/widgets/app_video_player.dart';
import '../../../shared/widgets/app_selectable_text.dart';
import '../../../shared/pages/app_text_editor_page.dart';
import '../../nearby/data/merchant_reviews_repository.dart';
import '../../nearby/presentation/merchant_reviews_page.dart';
import '../../user_space/data/space_cover_uploader.dart';
import '../../user_space/data/user_space_repository.dart';
import '../../user_space/domain/user_space.dart';
import '../../user_space/presentation/space_message_management_page.dart';
import '../data/moments_repository.dart';
import '../data/server_moments_repository.dart';
import '../domain/moment.dart';
import '../application/moment_notification_center.dart';
import 'moment_composer_page.dart';

class MyMomentsPage extends StatefulWidget {
  const MyMomentsPage({
    super.key,
    this.repository,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.allowPublishing = true,
    this.pageTitle,
    this.visibilityFilter,
    this.gender,
    this.region,
    this.signature,
    this.spaceRepository,
    this.coverUploader,
    this.reviewsRepository,
    this.notificationCenter,
  });

  final MomentsRepository? repository;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;
  final bool allowPublishing;
  final String? pageTitle;
  final MomentVisibility? visibilityFilter;
  final String? gender;
  final String? region;
  final String? signature;
  final UserSpaceRepository? spaceRepository;
  final SpaceCoverUploader? coverUploader;
  final MerchantReviewsRepository? reviewsRepository;
  final MomentNotificationCenter? notificationCenter;

  @override
  State<MyMomentsPage> createState() => _MyMomentsPageState();
}

class _MyMomentsPageState extends State<MyMomentsPage> {
  final ScrollController _scrollController = ScrollController();
  late final MomentsRepository _repository;
  late final String _userId;
  late final String _displayName;
  late final String _avatarUrl;
  late final bool _isOwner;
  late final UserSpaceRepository _spaceRepository;
  late final SpaceCoverUploader _coverUploader;
  late final MomentNotificationCenter _notificationCenter;
  List<Moment> _moments = const [];
  UserSpaceData? _space;
  final Set<String> _deletingMomentIds = {};
  bool _isLoading = true;
  bool _isLoadingSpace = true;
  bool _isUpdatingCover = false;

  @override
  void initState() {
    super.initState();
    final global = GlobalUtil();
    _repository = widget.repository ?? ServerMomentsRepository.instance;
    _userId = widget.userId ?? global.userName ?? '';
    _displayName =
        widget.displayName ??
        global.userInfoModel.nickName ??
        (_userId.isEmpty ? '我' : _userId);
    _avatarUrl = widget.avatarUrl ?? _buildCurrentAvatarUrl(global);
    _isOwner = widget.allowPublishing;
    _spaceRepository =
        widget.spaceRepository ??
        (_repository is LocalMomentsRepository
            ? InMemoryUserSpaceRepository(
                currentUserName: _isOwner ? _userId : 'viewer',
                initialData: UserSpaceData(
                  ownerUserName: _userId,
                  isOwner: _isOwner,
                ),
              )
            : ServerUserSpaceRepository());
    _coverUploader = widget.coverUploader ?? ServerSpaceCoverUploader();
    _notificationCenter =
        widget.notificationCenter ?? MomentNotificationCenter.instance;
    _notificationCenter.addListener(_handleNotificationChanged);
    if (_isOwner) unawaited(_notificationCenter.initialize());
    _loadMoments();
    _loadSpace();
  }

  void _handleNotificationChanged() {
    if (mounted) setState(() {});
  }

  Widget _buildNotificationAction() {
    return IconButton(
      key: const ValueKey('moment_notifications_button'),
      tooltip: '动态互动',
      onPressed: () => Navigator.pushNamed(context, '/momentNotifications'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded),
          if (_notificationCenter.hasUnread)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                key: const ValueKey('moment_notifications_appbar_dot'),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _buildCurrentAvatarUrl(GlobalUtil global) {
    final avatarName = global.userInfoModel.avatar ?? '';
    if (_userId.isEmpty || avatarName.isEmpty) return '';
    try {
      return global.getImageURL(_userId, avatarName);
    } catch (_) {
      return '';
    }
  }

  Future<void> _loadMoments() async {
    if (_repository case final CachedMomentsReader cachedRepository) {
      final cached = await cachedRepository.loadCachedMoments(_userId);
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _moments = _filterMoments(cached);
          _isLoading = false;
        });
      }
    }
    try {
      final loadedMoments = widget.allowPublishing
          ? await _repository.fetchOwnMoments(_userId)
          : await _repository.fetchUserMoments(_userId);
      final moments = _filterMoments(loadedMoments);
      if (!mounted) return;
      setState(() {
        _moments = moments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('加载动态失败：$error'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<Moment> _filterMoments(Iterable<Moment> moments) {
    return widget.visibilityFilter == null
        ? List<Moment>.of(moments)
        : moments
              .where((moment) => moment.visibility == widget.visibilityFilter)
              .toList(growable: false);
  }

  Future<void> _loadSpace() async {
    try {
      final space = await _spaceRepository.fetchSpace(_userId);
      if (!mounted) return;
      setState(() {
        _space = space;
        _isLoadingSpace = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _space = UserSpaceData(ownerUserName: _userId, isOwner: _isOwner);
        _isLoadingSpace = false;
      });
    }
  }

  Future<void> _changeCover() async {
    if (!_isOwner || _isUpdatingCover) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 1280,
    );
    if (image == null || !mounted) return;
    setState(() => _isUpdatingCover = true);
    try {
      final uploaded = await _coverUploader.upload(
        ownerUserName: _userId,
        localPath: image.path,
      );
      final coverUrl = await _spaceRepository.updateCover(uploaded);
      if (!mounted) return;
      setState(() {
        _space =
            (_space ?? UserSpaceData(ownerUserName: _userId, isOwner: true))
                .copyWith(coverImageUrl: coverUrl);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更换封面失败：$error')));
    } finally {
      if (mounted) setState(() => _isUpdatingCover = false);
    }
  }

  Future<void> _leaveMessage() async {
    if (_isOwner) return;
    final content = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AppTextEditorPage(
          title: '给$_displayName留言',
          initialValue: '',
          hintText: '写下你想说的话…',
          maxLength: 200,
          maxLines: 6,
          allowEmpty: false,
          emptyMessage: '请输入留言内容',
          saveText: '发表',
          fieldKey: const Key('space_message_editor_field'),
          saveButtonKey: const Key('publish_space_message_button'),
        ),
      ),
    );
    if (content == null || content.trim().isEmpty) return;
    try {
      final message = await _spaceRepository.addMessage(
        targetUserName: _userId,
        content: content,
      );
      if (!mounted) return;
      final current =
          _space ?? UserSpaceData(ownerUserName: _userId, isOwner: false);
      setState(() {
        _space = current.copyWith(messages: [message, ...current.messages]);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('留言已发表')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发表留言失败：$error')));
    }
  }

  Future<void> _manageMessages() async {
    if (!_isOwner) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SpaceMessageManagementPage(
          repository: _spaceRepository,
          ownerUserName: _userId,
          initialMessages: _space?.messages ?? const [],
        ),
      ),
    );
    await _loadSpace();
  }

  void _openReviews() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantReviewsPage(
          repository: widget.reviewsRepository,
          userId: _userId,
          pageTitle: _isOwner ? '我的点评' : '$_displayName的点评',
        ),
      ),
    );
  }

  void _scrollToMoments() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      430,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _notificationCenter.removeListener(_handleNotificationChanged);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openComposer() async {
    final published = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MomentComposerPage(
          repository: _repository,
          authorId: _userId,
          authorName: _displayName,
          authorAvatarUrl: _avatarUrl,
        ),
      ),
    );
    if (published == true) await _loadMoments();
  }

  Future<void> _toggleLike(Moment moment) async {
    try {
      final updated = await _repository.toggleLike(
        momentId: moment.id,
        userId: _userId,
      );
      _replaceMoment(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('点赞失败：$error'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _openCommentComposer(Moment moment) async {
    var commentDraft = '';
    final content = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextFormField(
                key: const Key('moment_comment_field'),
                autofocus: true,
                minLines: 1,
                maxLines: 4,
                maxLength: 200,
                onChanged: (value) => commentDraft = value,
                decoration: InputDecoration(
                  hintText: '评论这条动态……',
                  filled: true,
                  fillColor: context.appSearchBackground,
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: () {
                final value = commentDraft.trim();
                if (value.isNotEmpty) Navigator.pop(context, value);
              },
              child: const Text('发送'),
            ),
          ],
        ),
      ),
    );
    if (content == null || content.isEmpty) return;
    try {
      final updated = await _repository.addComment(
        momentId: moment.id,
        userId: _userId,
        displayName: _displayName,
        content: content,
      );
      _replaceMoment(updated);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('评论失败：$error'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _replaceMoment(Moment updated) {
    if (!mounted) return;
    setState(() {
      _moments = _moments
          .map((moment) => moment.id == updated.id ? updated : moment)
          .toList();
    });
  }

  Future<void> _deleteMoment(Moment moment) async {
    if (_deletingMomentIds.contains(moment.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条动态？'),
        content: const Text('动态、点赞、评论和媒体记录都会被删除，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm_delete_moment_button'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingMomentIds.add(moment.id));
    try {
      await _repository.deleteMoment(momentId: moment.id, userId: _userId);
      if (!mounted) return;
      setState(() {
        _moments = _moments
            .where((item) => item.id != moment.id)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('动态已删除'), duration: Duration(seconds: 2)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除动态失败：$error'),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingMomentIds.remove(moment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        title: Text(
          widget.pageTitle ?? (_isOwner ? '我的空间' : '$_displayName的空间'),
        ),
        actions: _isOwner ? [_buildNotificationAction()] : null,
      ),
      floatingActionButton: widget.allowPublishing
          ? FloatingActionButton.extended(
              key: const Key('moment_publish_fab'),
              onPressed: _openComposer,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('发动态'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadMoments,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _SpaceProfileHeader(
                userId: _userId,
                displayName: _displayName,
                avatarUrl: _avatarUrl,
                momentCount: _moments.length,
                isOwner: _isOwner,
                gender:
                    widget.gender ??
                    (_isOwner
                        ? userGenderLabel(GlobalUtil().userInfoModel.gender)
                        : null),
                region:
                    widget.region ??
                    (_isOwner ? GlobalUtil().userInfoModel.region : null),
                signature:
                    widget.signature ??
                    (_isOwner ? GlobalUtil().userInfoModel.signature : null),
                coverImageUrl: _space?.coverImageUrl ?? '',
                messages: _space?.messages ?? const [],
                loadingSpace: _isLoadingSpace,
                updatingCover: _isUpdatingCover,
                onChangeCover: _changeCover,
                onLeaveMessage: _leaveMessage,
                onManageMessages: _manageMessages,
                onOpenMoments: _scrollToMoments,
                onOpenReviews: _openReviews,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 2),
                child: Row(
                  children: [
                    Text(
                      _isOwner ? '我的动态' : '他的动态',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_moments.length} 条',
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_moments.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyMoments(
                  allowCreate: widget.allowPublishing,
                  onCreate: _openComposer,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                sliver: SliverList.separated(
                  itemCount: _moments.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final moment = _moments[index];
                    return _MomentCard(
                      moment: moment,
                      onLike: () => _toggleLike(moment),
                      onComment: () => _openCommentComposer(moment),
                      onDelete: widget.allowPublishing
                          ? () => _deleteMoment(moment)
                          : null,
                      isDeleting: _deletingMomentIds.contains(moment.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SpaceProfileHeader extends StatelessWidget {
  const _SpaceProfileHeader({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.momentCount,
    required this.isOwner,
    required this.coverImageUrl,
    required this.messages,
    required this.loadingSpace,
    required this.updatingCover,
    required this.onChangeCover,
    required this.onLeaveMessage,
    required this.onManageMessages,
    required this.onOpenMoments,
    required this.onOpenReviews,
    this.gender,
    this.region,
    this.signature,
  });

  final String userId;
  final String displayName;
  final String avatarUrl;
  final int momentCount;
  final bool isOwner;
  final String coverImageUrl;
  final List<SpaceGuestbookMessage> messages;
  final bool loadingSpace;
  final bool updatingCover;
  final VoidCallback onChangeCover;
  final VoidCallback onLeaveMessage;
  final VoidCallback onManageMessages;
  final VoidCallback onOpenMoments;
  final VoidCallback onOpenReviews;
  final String? gender;
  final String? region;
  final String? signature;

  @override
  Widget build(BuildContext context) {
    final profileParts = <String>[
      if ((gender ?? '').trim().isNotEmpty) gender!.trim(),
      if ((region ?? '').trim().isNotEmpty) region!.trim(),
    ];
    return ColoredBox(
      color: context.appSurface,
      child: Column(
        children: [
          SizedBox(
            height: 250,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _SpaceCover(imageUrl: coverImageUrl),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x55000000)],
                    ),
                  ),
                ),
                if (!loadingSpace)
                  _SpaceDanmaku(messages: messages.take(5).toList()),
                if (isOwner)
                  Positioned(
                    right: 14,
                    top: 12,
                    child: _CoverActionButton(
                      key: const Key('change_space_cover_button'),
                      icon: updatingCover
                          ? Icons.hourglass_top_rounded
                          : Icons.photo_camera_outlined,
                      label: updatingCover ? '上传中' : '更换封面',
                      onTap: updatingCover ? null : onChangeCover,
                    ),
                  ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _MomentAvatar(
                        avatarUrl: avatarUrl,
                        displayName: displayName,
                        radius: 42,
                        borderWidth: 4,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '账号：$userId',
                                style: TextStyle(
                                  color: context.appTextSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: Key(
                          isOwner
                              ? 'manage_space_messages_button'
                              : 'leave_space_message_button',
                        ),
                        onPressed: isOwner ? onManageMessages : onLeaveMessage,
                        icon: Icon(
                          isOwner
                              ? Icons.tune_rounded
                              : Icons.chat_bubble_outline_rounded,
                          size: 17,
                        ),
                        label: Text(isOwner ? '管理留言' : '留言'),
                      ),
                    ],
                  ),
                  if (profileParts.isNotEmpty ||
                      (signature ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        [
                          if (profileParts.isNotEmpty) profileParts.join(' · '),
                          if ((signature ?? '').trim().isNotEmpty)
                            signature!.trim(),
                        ].join('   '),
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: context.appSearchBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SpaceShortcut(
                            key: const Key('space_moments_shortcut'),
                            icon: Icons.photo_library_outlined,
                            title: isOwner ? '我的动态' : '他的动态',
                            subtitle: '$momentCount 条动态',
                            onTap: onOpenMoments,
                          ),
                        ),
                        Container(
                          height: 54,
                          width: 0.5,
                          color: context.appDivider,
                        ),
                        Expanded(
                          child: _SpaceShortcut(
                            key: const Key('space_reviews_shortcut'),
                            icon: Icons.storefront_outlined,
                            title: isOwner ? '我的点评' : '他的点评',
                            subtitle: '查看收藏与点评',
                            onTap: onOpenReviews,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpaceCover extends StatelessWidget {
  const _SpaceCover({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDDF5E7), Color(0xFFBCE8CF)],
          ),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: AppImageCache.manager,
      fit: BoxFit.cover,
      placeholder: (_, _) => const ColoredBox(color: Color(0xFFDDF5E7)),
      errorWidget: (_, _, _) => const ColoredBox(color: Color(0xFFDDF5E7)),
    );
  }
}

class _SpaceDanmaku extends StatelessWidget {
  const _SpaceDanmaku({required this.messages});

  final List<SpaceGuestbookMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: [
          for (var index = 0; index < messages.length; index++)
            Positioned(
              left: 0,
              right: 0,
              top: 50 + (index % 3) * 48,
              height: 36,
              child: _DanmakuLane(
                key: ValueKey('space-danmaku-${messages[index].id}'),
                text:
                    '${messages[index].authorNickName}: ${messages[index].content}',
                delay: Duration(milliseconds: index * 850),
              ),
            ),
        ],
      ),
    );
  }
}

class _DanmakuLane extends StatefulWidget {
  const _DanmakuLane({super.key, required this.text, required this.delay});

  final String text;
  final Duration delay;

  @override
  State<_DanmakuLane> createState() => _DanmakuLaneState();
}

class _DanmakuLaneState extends State<_DanmakuLane>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 8 + (widget.text.length / 8).round()),
    );
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final estimatedWidth = (widget.text.characters.length * 15 + 34)
            .clamp(120, 360)
            .toDouble();
        return ClipRect(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final x =
                  constraints.maxWidth -
                  (_controller.value * (constraints.maxWidth + estimatedWidth));
              return Transform.translate(offset: Offset(x, 0), child: child);
            },
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  widget.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoverActionButton extends StatelessWidget {
  const _CoverActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpaceShortcut extends StatelessWidget {
  const _SpaceShortcut({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.appTextSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmptyMoments extends StatelessWidget {
  const _EmptyMoments({required this.allowCreate, required this.onCreate});

  final bool allowCreate;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const Key('moments_empty_state'),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5EC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              allowCreate ? '还没有发布过动态' : '暂无可见动态',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            Text(
              allowCreate ? '记录生活片段，在这里回看自己的每一刻' : '对方还没有发布你可以查看的动态',
              style: TextStyle(color: context.appTextSecondary, fontSize: 13),
            ),
            if (allowCreate) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('发布第一条动态'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({
    required this.moment,
    required this.onLike,
    required this.onComment,
    this.onDelete,
    this.isDeleting = false,
  });

  final Moment moment;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('moment-${moment.id}'),
      color: context.appSurface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _MomentAvatar(
                  avatarUrl: moment.authorAvatarUrl,
                  displayName: moment.authorName,
                  radius: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moment.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatMomentTime(moment.createdAt),
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _VisibilityBadge(visibility: moment.visibility),
                if (onDelete != null)
                  PopupMenuButton<String>(
                    key: ValueKey('moment-menu-${moment.id}'),
                    enabled: !isDeleting,
                    tooltip: '动态操作',
                    icon: isDeleting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.more_horiz, size: 21),
                    onSelected: (value) {
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.redAccent),
                            SizedBox(width: 10),
                            Text(
                              '删除动态',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (moment.content.isNotEmpty) ...[
              const SizedBox(height: 13),
              AppSelectableText(
                moment.content,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
            if (moment.mediaPaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MomentMediaGrid(
                paths: moment.mediaPaths,
                thumbnails: moment.mediaThumbnails,
                localPaths: moment.localMediaPaths,
                localThumbnailPaths: moment.localThumbnailPaths,
              ),
            ],
            if (moment.location?.isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    moment.location!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    key: ValueKey('like-${moment.id}'),
                    onPressed: onLike,
                    icon: Icon(
                      moment.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 19,
                      color: moment.isLiked ? Colors.redAccent : null,
                    ),
                    label: Text(
                      moment.likeCount == 0 ? '点赞' : '${moment.likeCount}',
                    ),
                  ),
                ),
                Container(width: 1, height: 18, color: context.appDivider),
                Expanded(
                  child: TextButton.icon(
                    key: ValueKey('comment-${moment.id}'),
                    onPressed: onComment,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text(
                      moment.comments.isEmpty
                          ? '评论'
                          : '${moment.comments.length}',
                    ),
                  ),
                ),
              ],
            ),
            if (moment.comments.isNotEmpty)
              _CommentsPreview(comments: moment.comments),
          ],
        ),
      ),
    );
  }
}

class _MomentAvatar extends StatelessWidget {
  const _MomentAvatar({
    required this.avatarUrl,
    required this.displayName,
    required this.radius,
    this.borderWidth = 0,
  });

  final String avatarUrl;
  final String displayName;
  final double radius;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final initial = displayName.trim().isEmpty
        ? '?'
        : displayName.trim().characters.first;
    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        color: context.appSurface,
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE3EEE8),
        backgroundImage: avatarUrl.isEmpty
            ? null
            : AppImageCache.provider(avatarUrl),
        child: avatarUrl.isEmpty
            ? Text(
                initial,
                style: TextStyle(
                  fontSize: radius * .72,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }
}

class _MomentMediaGrid extends StatelessWidget {
  const _MomentMediaGrid({
    required this.paths,
    required this.thumbnails,
    required this.localPaths,
    required this.localThumbnailPaths,
  });

  final List<String> paths;
  final Map<String, String> thumbnails;
  final Map<String, String> localPaths;
  final Map<String, String> localThumbnailPaths;

  bool _isRemote(String path) =>
      path.startsWith('http://') || path.startsWith('https://');

  String? _existingLocal(Map<String, String> values, String remoteUrl) {
    final path = values[remoteUrl];
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 0 ? path : null;
  }

  String _fileName(String path) {
    final uri = Uri.tryParse(path);
    final candidate =
        uri?.queryParameters['imageName'] ??
        uri?.queryParameters['videoName'] ??
        (uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : path);
    return candidate.trim().isEmpty
        ? (isVideoPath(path) ? 'moment_video.mp4' : 'moment_image.jpg')
        : candidate;
  }

  Future<void> _save(BuildContext context, String path) async {
    try {
      if (isVideoPath(path)) {
        final localPath = _existingLocal(localPaths, path);
        await const ChatMediaSaver().saveVideo(
          source: path,
          fileName: _fileName(path),
          localPath: localPath ?? (_isRemote(path) ? null : path),
        );
      } else {
        await const ChatMediaSaver().saveImage(
          source: path,
          fileName: _fileName(path),
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isVideoPath(path) ? '视频已保存到系统相册' : '照片已保存到系统相册'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存失败，请检查相册权限')));
      }
    }
  }

  Future<void> _showSaveMenu(BuildContext context, String path) async {
    final save = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('save_moment_media'),
              leading: const Icon(Icons.download_rounded),
              title: const Text('保存到本地'),
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (save == true && context.mounted) await _save(context, path);
  }

  @override
  Widget build(BuildContext context) {
    final count = paths.length.clamp(1, 9);
    final columns = count == 1 ? 1 : (count == 2 || count == 4 ? 2 : 3);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = count == 1
            ? constraints.maxWidth * .72
            : constraints.maxWidth;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: maxWidth,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: count,
              itemBuilder: (context, index) {
                final path = paths[index];
                if (isVideoPath(path)) {
                  final localPath = _existingLocal(localPaths, path);
                  final localThumbnailPath = _existingLocal(
                    localThumbnailPaths,
                    path,
                  );
                  return AppVideoPreview(
                    key: ValueKey('moment_video_$index'),
                    source: localPath ?? path,
                    isLocal: localPath != null || !_isRemote(path),
                    width: double.infinity,
                    height: double.infinity,
                    fileName: _fileName(path),
                    coverSource: localThumbnailPath ?? thumbnails[path],
                    coverIsLocal: localThumbnailPath != null,
                    autoCacheRemote: localPath == null && _isRemote(path),
                    onLongPress: () => _showSaveMenu(context, path),
                  );
                }
                final imageProvider =
                    path.startsWith('http://') || path.startsWith('https://')
                    ? AppImageCache.provider(path)
                    : FileImage(File(path));
                return GestureDetector(
                  key: ValueKey('moment_image_$index'),
                  onTap: () => showFullscreenImage(
                    context,
                    imageProvider: imageProvider,
                    onSave: () => _save(context, path),
                  ),
                  onLongPress: () => _showSaveMenu(context, path),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child:
                        path.startsWith('http://') ||
                            path.startsWith('https://')
                        ? CachedNetworkImage(
                            cacheManager: AppImageCache.manager,
                            imageUrl: path,
                            cacheKey: AppImageCache.cacheKey(path),
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => ColoredBox(
                              color: context.appSearchBackground,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          )
                        : Image.file(
                            File(path),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: context.appSearchBackground,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _VisibilityBadge extends StatelessWidget {
  const _VisibilityBadge({required this.visibility});

  final MomentVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final label = switch (visibility) {
      MomentVisibility.public => '公开',
      MomentVisibility.friendsOnly => '好友',
      MomentVisibility.private => '私密',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.appSearchBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_outlined, size: 12),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _CommentsPreview extends StatelessWidget {
  const _CommentsPreview({required this.comments});

  final List<MomentComment> comments;

  @override
  Widget build(BuildContext context) {
    final preview = comments.take(3).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appSearchBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final comment in preview)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${comment.displayName}：',
                      style: const TextStyle(
                        color: Color(0xFF3A6652),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(text: comment.content),
                  ],
                ),
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
          if (comments.length > preview.length)
            Text(
              '查看全部 ${comments.length} 条评论',
              style: const TextStyle(color: Color(0xFF3A6652), fontSize: 12),
            ),
        ],
      ),
    );
  }
}

String _formatMomentTime(DateTime time) {
  final now = DateTime.now();
  final difference = now.difference(time);
  if (difference.inMinutes < 1) return '刚刚';
  if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
  if (difference.inDays < 1) return '${difference.inHours} 小时前';
  if (time.year == now.year) return DateFormat('MM月dd日 HH:mm').format(time);
  return DateFormat('yyyy年MM月dd日').format(time);
}
