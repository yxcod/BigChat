import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/cache/app_image_cache.dart';
import '../../../utils/gloabl.dart';
import '../data/moments_repository.dart';
import '../data/server_moments_repository.dart';
import '../domain/moment.dart';
import 'moment_composer_page.dart';

class MyMomentsPage extends StatefulWidget {
  const MyMomentsPage({
    super.key,
    this.repository,
    this.userId,
    this.displayName,
    this.avatarUrl,
  });

  final MomentsRepository? repository;
  final String? userId;
  final String? displayName;
  final String? avatarUrl;

  @override
  State<MyMomentsPage> createState() => _MyMomentsPageState();
}

class _MyMomentsPageState extends State<MyMomentsPage> {
  late final MomentsRepository _repository;
  late final String _userId;
  late final String _displayName;
  late final String _avatarUrl;
  List<Moment> _moments = const [];
  bool _isLoading = true;

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
    _loadMoments();
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
    try {
      final moments = await _repository.fetchOwnMoments(_userId);
      if (!mounted) return;
      setState(() {
        _moments = moments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('加载动态失败：$error')));
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('点赞失败：$error')));
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
                  fillColor: AppColors.searchBackground,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('评论失败：$error')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        title: const Text('我的动态'),
        actions: [
          IconButton(
            key: const Key('moment_compose_button'),
            tooltip: '发布动态',
            onPressed: _openComposer,
            icon: const Icon(Icons.camera_alt_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('发动态'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMoments,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                userId: _userId,
                displayName: _displayName,
                avatarUrl: _avatarUrl,
                momentCount: _moments.length,
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
                child: _EmptyMoments(onCreate: _openComposer),
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.momentCount,
  });

  final String userId;
  final String displayName;
  final String avatarUrl;
  final int momentCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: 118,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF315C48), Color(0xFF86B59B)],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Column(
              children: [
                _MomentAvatar(
                  avatarUrl: avatarUrl,
                  displayName: displayName,
                  radius: 38,
                  borderWidth: 4,
                ),
                const SizedBox(height: 8),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$userId  ·  $momentCount 条动态',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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

class _EmptyMoments extends StatelessWidget {
  const _EmptyMoments({required this.onCreate});

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
            const Text(
              '还没有发布过动态',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            const Text(
              '记录生活片段，在这里回看自己的每一刻',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('发布第一条动态'),
            ),
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
  });

  final Moment moment;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('moment-${moment.id}'),
      color: Colors.white,
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _VisibilityBadge(visibility: moment.visibility),
              ],
            ),
            if (moment.content.isNotEmpty) ...[
              const SizedBox(height: 13),
              Text(
                moment.content,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ],
            if (moment.mediaPaths.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MomentMediaGrid(paths: moment.mediaPaths),
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
                Container(width: 1, height: 18, color: AppColors.divider),
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
      decoration: const BoxDecoration(
        color: Colors.white,
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
  const _MomentMediaGrid({required this.paths});

  final List<String> paths;

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
                return ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child:
                      path.startsWith('http://') || path.startsWith('https://')
                      ? CachedNetworkImage(
                          cacheManager: AppImageCache.manager,
                          imageUrl: path,
                          cacheKey: AppImageCache.cacheKey(path),
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => const ColoredBox(
                            color: AppColors.searchBackground,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        )
                      : Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: AppColors.searchBackground,
                            child: Icon(Icons.broken_image_outlined),
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
        color: AppColors.searchBackground,
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
        color: AppColors.searchBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final comment in preview)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(
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
