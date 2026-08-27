import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../data/user_space_repository.dart';
import '../domain/user_space.dart';

class SpaceMessageManagementPage extends StatefulWidget {
  const SpaceMessageManagementPage({
    super.key,
    required this.repository,
    required this.ownerUserName,
    required this.initialMessages,
  });

  final UserSpaceRepository repository;
  final String ownerUserName;
  final List<SpaceGuestbookMessage> initialMessages;

  @override
  State<SpaceMessageManagementPage> createState() =>
      _SpaceMessageManagementPageState();
}

class _SpaceMessageManagementPageState
    extends State<SpaceMessageManagementPage> {
  late List<SpaceGuestbookMessage> _messages;

  @override
  void initState() {
    super.initState();
    _messages = List.of(widget.initialMessages);
  }

  Future<bool> _delete(SpaceGuestbookMessage message) async {
    try {
      await widget.repository.deleteMessage(message.id);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('留言管理'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: context.appDivider),
        ),
      ),
      body: _messages.isEmpty
          ? Center(
              child: Text(
                '暂时还没有留言',
                style: TextStyle(color: context.appTextSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              itemCount: _messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Dismissible(
                  key: ValueKey('space-message-${message.id}'),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _delete(message),
                  onDismissed: (_) {
                    setState(
                      () => _messages.removeWhere(
                        (item) => item.id == message.id,
                      ),
                    );
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('留言已删除')));
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  child: _MessageCard(message: message),
                );
              },
            ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final SpaceGuestbookMessage message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE5F7ED),
            backgroundImage: message.authorAvatarUrl.isEmpty
                ? null
                : CachedNetworkImageProvider(message.authorAvatarUrl),
            child: message.authorAvatarUrl.isEmpty
                ? Text(
                    message.authorNickName.isEmpty
                        ? '友'
                        : message.authorNickName.characters.first,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.authorNickName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      DateFormat('MM-dd HH:mm').format(message.createdAt),
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  message.content,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 15,
                    height: 1.45,
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
