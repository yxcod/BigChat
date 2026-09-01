import 'package:flutter/material.dart';

import '../../../shared/widgets/app_back_button.dart';
import '../../../app/theme/app_theme_context.dart';

import '../domain/group_resource.dart';
import 'group_resource_list_page.dart';

class GroupResourcesPage extends StatelessWidget {
  const GroupResourcesPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });
  final int groupId;
  final String groupName;

  void _open(BuildContext context, GroupResourceType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupResourceListPage(
          groupId: groupId,
          groupName: groupName,
          type: type,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(leading: const AppBackButton(), title: const Text('群资源')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                groupName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                '群成员共享的文件、照片与视频',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  _ResourceEntry(
                    icon: Icons.folder_rounded,
                    color: const Color(0xFFFFB41F),
                    label: '群文件',
                    onTap: () => _open(context, GroupResourceType.file),
                  ),
                  const SizedBox(width: 38),
                  _ResourceEntry(
                    icon: Icons.photo_library_rounded,
                    color: const Color(0xFF2B9DF4),
                    label: '群相册',
                    onTap: () => _open(context, GroupResourceType.album),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceEntry extends StatelessWidget {
  const _ResourceEntry({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 8),
          Text(label),
        ],
      ),
    ),
  );
}
