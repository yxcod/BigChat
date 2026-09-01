import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../core/cache/app_image_cache.dart';
import '../../../utils/gloabl.dart';
import '../application/moment_notification_center.dart';
import '../domain/moment_interaction_notification.dart';

class MomentNotificationsPage extends StatefulWidget {
  const MomentNotificationsPage({super.key, this.notificationCenter});

  final MomentNotificationCenter? notificationCenter;

  @override
  State<MomentNotificationsPage> createState() =>
      _MomentNotificationsPageState();
}

class _MomentNotificationsPageState extends State<MomentNotificationsPage> {
  late final MomentNotificationCenter _center;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _center = widget.notificationCenter ?? MomentNotificationCenter.instance;
    _center.addListener(_handleChanged);
    _load();
  }

  @override
  void dispose() {
    _center.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _center.initialize();
    if (mounted) setState(() => _loading = false);
    await _center.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final items = _center.items;
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        title: const Text('动态互动'),
        centerTitle: true,
        backgroundColor: context.appSurface,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: _loading && items.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 52,
                    color: Color(0xFFB8BDC5),
                  ),
                  SizedBox(height: 14),
                  Center(child: Text('还没有动态互动')),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _NotificationTile(
                  notification: items[index],
                  onTap: () => Navigator.pushNamed(context, '/myMoments'),
                ),
              ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final MomentInteractionNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('moment_notification_${notification.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActorAvatar(notification: notification),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: notification.displayActorName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: ' ${notification.actionText}'),
                        ],
                      ),
                    ),
                    if (notification.type == MomentInteractionType.comment &&
                        notification.commentContent.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: context.appSearchBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          notification.commentContent.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      DateFormat('MM-dd HH:mm').format(notification.createdAt),
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                notification.type == MomentInteractionType.like
                    ? Icons.favorite_rounded
                    : Icons.mode_comment_rounded,
                color: notification.type == MomentInteractionType.like
                    ? const Color(0xFFFF5B68)
                    : AppColors.primary,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({required this.notification});

  final MomentInteractionNotification notification;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarUrl();
    final fallback = CircleAvatar(
      radius: 23,
      backgroundColor: const Color(0xFFEAF8F0),
      child: Text(
        notification.displayActorName.isEmpty
            ? '友'
            : notification.displayActorName.substring(0, 1),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    if (avatarUrl.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        cacheManager: AppImageCache.manager,
        imageUrl: avatarUrl,
        cacheKey: AppImageCache.cacheKey(avatarUrl),
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }

  String _avatarUrl() {
    final value = notification.actorAvatarUrl.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    try {
      return GlobalUtil().getImageURL(notification.actorUserId, value);
    } catch (_) {
      return '';
    }
  }
}
