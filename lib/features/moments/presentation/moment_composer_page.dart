import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../data/moment_media_uploader.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../data/moments_repository.dart';
import '../domain/moment.dart';
import '../../../core/media/video_media.dart';
import '../../../shared/widgets/app_video_player.dart';
import '../../location/data/app_location_service.dart';

class MomentComposerPage extends StatefulWidget {
  const MomentComposerPage({
    super.key,
    required this.repository,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    this.mediaUploader,
  });

  final MomentsRepository repository;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final MomentMediaUploader? mediaUploader;

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
  bool _isLocating = false;

  bool get _canPublish =>
      _contentController.text.trim().isNotEmpty || _mediaPaths.isNotEmpty;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_mediaPaths.any(isVideoPath)) return;
    final remaining = 9 - _mediaPaths.length;
    if (remaining <= 0) return;
    final images = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (!mounted || images.isEmpty) return;
    setState(() {
      _mediaPaths.addAll(images.take(remaining).map((image) => image.path));
    });
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      await validateVideoFile(video.path);
      if (mounted)
        setState(() {
          _mediaPaths
            ..clear()
            ..add(video.path);
        });
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法选择视频：$error')));
    }
  }

  Future<void> _chooseMedia() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('选择图片'),
              subtitle: const Text('最多9张'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('选择视频'),
              subtitle: const Text('单个视频不超过300MB'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'image') await _pickImages();
    if (choice == 'video') await _pickVideo();
  }

  Future<void> _publish() async {
    if (!_canPublish || _isPublishing) return;
    setState(() => _isPublishing = true);
    try {
      final mediaPaths = _mediaPaths.isEmpty
          ? const <String>[]
          : await (widget.mediaUploader ?? ServerMomentMediaUploader()).upload(
              authorId: widget.authorId,
              localPaths: _mediaPaths,
            );
      await widget.repository.publish(
        MomentDraft(
          authorId: widget.authorId,
          authorName: widget.authorName,
          authorAvatarUrl: widget.authorAvatarUrl,
          content: _contentController.text,
          mediaPaths: mediaPaths,
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
    if (_isLocating) return;
    var editedLocation = _location ?? '';
    setState(() => _isLocating = true);
    try {
      final place = await AppLocationService().locate().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('定位超时'),
      );
      editedLocation = place.address;
      if (mounted) setState(() => _location = place.address);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('自动定位失败：$error，可手动填写位置')));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
    if (!mounted) return;
    final location = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('所在位置'),
        content: TextFormField(
          key: const Key('moment_location_field'),
          initialValue: editedLocation,
          autofocus: true,
          maxLength: 30,
          onChanged: (value) => editedLocation = value,
          decoration: const InputDecoration(hintText: '例如：上海·徐家汇'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('不显示'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editedLocation.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
            onAdd: _chooseMedia,
            onRemove: (path) => setState(() => _mediaPaths.remove(path)),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1),
          ListTile(
            key: const Key('moment_location_button'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('所在位置'),
            trailing: _isLocating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
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
    final hasVideo = paths.any(isVideoPath);
    final count = paths.length + (!hasVideo && paths.length < 9 ? 1 : 0);
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
                  Text('图片/视频', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        }
        final path = paths[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            if (isVideoPath(path))
              AppVideoPreview(
                source: path,
                isLocal: true,
                width: double.infinity,
                height: double.infinity,
              )
            else
              GestureDetector(
                onTap: () => showFullscreenImage(
                  context,
                  imageProvider: FileImage(File(path)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(path), fit: BoxFit.cover),
                ),
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
