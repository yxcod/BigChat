import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../data/moments_repository.dart';
import '../domain/moment.dart';

class MomentComposerPage extends StatefulWidget {
  const MomentComposerPage({
    super.key,
    required this.repository,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
  });

  final MomentsRepository repository;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;

  @override
  State<MomentComposerPage> createState() => _MomentComposerPageState();
}

class _MomentComposerPageState extends State<MomentComposerPage> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _mediaPaths = [];
  MomentVisibility _visibility = MomentVisibility.public;
  String? _location;
  bool _isPublishing = false;

  bool get _canPublish =>
      _contentController.text.trim().isNotEmpty || _mediaPaths.isNotEmpty;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 9 - _mediaPaths.length;
    if (remaining <= 0) return;
    final images = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (!mounted || images.isEmpty) return;
    setState(() {
      _mediaPaths.addAll(images.take(remaining).map((image) => image.path));
    });
  }

  Future<void> _publish() async {
    if (!_canPublish || _isPublishing) return;
    setState(() => _isPublishing = true);
    try {
      await widget.repository.publish(
        MomentDraft(
          authorId: widget.authorId,
          authorName: widget.authorName,
          authorAvatarUrl: widget.authorAvatarUrl,
          content: _contentController.text,
          mediaPaths: _mediaPaths,
          visibility: _visibility,
          location: _location,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发布失败：$error')));
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _chooseVisibility() async {
    final selected = await showModalBottomSheet<MomentVisibility>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('谁可以看'),
              subtitle: Text('后续接入后端时直接传递该可见范围'),
            ),
            ...MomentVisibility.values.map(
              (visibility) => ListTile(
                title: Text(_visibilityLabel(visibility)),
                trailing: visibility == _visibility
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, visibility),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _visibility = selected);
    }
  }

  Future<void> _editLocation() async {
    final controller = TextEditingController(text: _location);
    final location = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('所在位置'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          decoration: const InputDecoration(hintText: '例如：上海·徐家汇'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('不显示'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (location != null && mounted) {
      setState(() => _location = location.isEmpty ? null : location);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.maybePop(context),
          child: const Text('取消'),
        ),
        leadingWidth: 64,
        title: const Text('发布动态'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('publish_moment_button'),
              onPressed: _canPublish && !_isPublishing ? _publish : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(64, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _isPublishing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('发布'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        children: [
          TextField(
            key: const Key('moment_content_field'),
            controller: _contentController,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '记录这一刻的想法……',
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          _MediaGrid(
            paths: _mediaPaths,
            onAdd: _pickImages,
            onRemove: (path) => setState(() => _mediaPaths.remove(path)),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('所在位置'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _location ?? '不显示',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _editLocation,
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('谁可以看'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _visibilityLabel(_visibility),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: _chooseVisibility,
          ),
        ],
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({
    required this.paths,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> paths;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final count = paths.length + (paths.length < 9 ? 1 : 0);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: count,
      itemBuilder: (context, index) {
        if (index == paths.length) {
          return InkWell(
            key: const Key('add_moment_images'),
            onTap: onAdd,
            borderRadius: BorderRadius.circular(10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.searchBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 30),
                  SizedBox(height: 6),
                  Text('图片', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        }
        final path = paths[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(File(path), fit: BoxFit.cover),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: () => onRemove(path),
                child: const CircleAvatar(
                  radius: 11,
                  backgroundColor: Color(0x99000000),
                  child: Icon(Icons.close, size: 15, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _visibilityLabel(MomentVisibility visibility) {
  return switch (visibility) {
    MomentVisibility.public => '公开',
    MomentVisibility.friendsOnly => '仅好友',
    MomentVisibility.private => '仅自己',
  };
}
