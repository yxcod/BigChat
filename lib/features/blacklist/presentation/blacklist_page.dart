import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../core/cache/app_image_cache.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../utils/gloabl.dart';
import '../data/blacklist_repository.dart';

class BlacklistPage extends StatefulWidget {
  const BlacklistPage({super.key, this.repository});

  final BlacklistRepository? repository;

  @override
  State<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends State<BlacklistPage> {
  late final BlacklistRepository _repository;
  List<BlockedUser> _items = const [];
  bool _loading = true;
  String? _busyUserName;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? BlacklistRepository();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repository.load();
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) _showMessage('黑名单加载失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移出黑名单'),
        content: Text('确定将“${user.displayName}”移出黑名单吗？\n移出后不会自动恢复好友关系。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyUserName = user.userName);
    try {
      await _repository.unblock(user.userName);
      if (!mounted) return;
      setState(
        () => _items = _items
            .where((item) => item.userName != user.userName)
            .toList(growable: false),
      );
      _showMessage('已移出黑名单');
    } catch (error) {
      if (mounted) _showMessage('移出失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busyUserName = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('黑名单管理'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.appDivider),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? Center(
              child: Text(
                '黑名单为空',
                style: TextStyle(color: context.appTextSecondary, fontSize: 15),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _items.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, indent: 82, color: context.appDivider),
              itemBuilder: (context, index) {
                final user = _items[index];
                return _BlockedUserTile(
                  user: user,
                  busy: _busyUserName == user.userName,
                  onUnblock: () => _unblock(user),
                );
              },
            ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  const _BlockedUserTile({
    required this.user,
    required this.busy,
    required this.onUnblock,
  });

  final BlockedUser user;
  final bool busy;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final global = GlobalUtil();
    final imageUrl = user.avatar.isEmpty
        ? ''
        : global.getImageURL(
            user.userName,
            user.avatar,
            version: user.avatarVersion,
          );
    return ColoredBox(
      color: context.appSurface,
      child: ListTile(
        minTileHeight: 72,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: context.appPageBackground,
          child: imageUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.grey)
              : ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    cacheKey: AppImageCache.cacheKey(imageUrl),
                    cacheManager: AppImageCache.manager,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
        ),
        title: Text(
          user.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '账号：${user.userName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: context.appTextSecondary),
        ),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton(
                onPressed: onUnblock,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                child: const Text('移出'),
              ),
      ),
    );
  }
}
