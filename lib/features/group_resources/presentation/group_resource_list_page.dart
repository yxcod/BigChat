import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_back_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/cache/app_image_cache.dart';
import '../../../core/media/chat_file_saver.dart';
import '../../../core/media/chat_media_saver.dart';
import '../../../core/media/video_media.dart';
import '../../../shared/widgets/app_video_player.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../utils/http.dart';
import '../../../app/theme/app_theme_context.dart';
import '../data/group_resource_repository.dart';
import '../domain/group_resource.dart';

enum GroupResourceUploadKind { photo, video, file }

class GroupResourceUploadDraft {
  const GroupResourceUploadDraft({
    required this.path,
    required this.name,
    required this.size,
    required this.kind,
  });

  final String path;
  final String name;
  final int size;
  final GroupResourceUploadKind kind;
}

typedef GroupResourcePicker =
    Future<GroupResourceUploadDraft?> Function(GroupResourceUploadKind kind);

class GroupResourceListPage extends StatefulWidget {
  const GroupResourceListPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.type,
    this.repository,
    this.picker,
  });
  final int groupId;
  final String groupName;
  final GroupResourceType type;
  final GroupResourceRepository? repository;
  final GroupResourcePicker? picker;
  @override
  State<GroupResourceListPage> createState() => _GroupResourceListPageState();
}

class _GroupResourceListPageState extends State<GroupResourceListPage> {
  late final GroupResourceRepository _repository =
      widget.repository ?? GroupResourceRepository();
  List<GroupResource> _items = const [];
  final List<_PendingGroupResource> _pending = [];
  bool _loading = true;
  bool _uploading = false;
  double? _progress;

  bool get _isAlbum => widget.type == GroupResourceType.album;

  @override
  void initState() {
    super.initState();
    _items = _repository.loadCached(widget.groupId, widget.type);
    _loading = _items.isEmpty;
    _load();
  }

  Future<void> _load() async {
    if (mounted && _items.isEmpty) setState(() => _loading = true);
    try {
      final items = await _repository.list(widget.groupId, widget.type);
      if (mounted) {
        setState(() {
          _items = items;
          _pending.removeWhere((item) => item.completed);
        });
      }
    } catch (error) {
      if (mounted) _message('加载失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseAndUpload() async {
    if (!_isAlbum) {
      await _pickAndUpload();
      return;
    }
    final kind = await showModalBottomSheet<GroupResourceUploadKind>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('group_album_upload_photo'),
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('上传照片'),
              subtitle: const Text('支持 JPEG、PNG、WebP，最大 5MB'),
              onTap: () =>
                  Navigator.pop(context, GroupResourceUploadKind.photo),
            ),
            ListTile(
              key: const Key('group_album_upload_video'),
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('上传视频'),
              subtitle: const Text('支持 MP4、MOV、M4V，最大 300MB'),
              onTap: () =>
                  Navigator.pop(context, GroupResourceUploadKind.video),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (kind != null) await _pickAndUpload(albumKind: kind);
  }

  Future<void> _pickAndUpload({GroupResourceUploadKind? albumKind}) async {
    if (_uploading) return;
    final kind = albumKind ?? GroupResourceUploadKind.file;
    final draft = widget.picker == null
        ? await _pickNative(kind)
        : await widget.picker!(kind);
    if (draft == null || !mounted) return;
    final pendingId = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _uploading = true;
      _pending.insert(
        0,
        _PendingGroupResource(
          id: pendingId,
          path: draft.path,
          name: draft.name,
          size: draft.size,
          kind: draft.kind,
          progress: 0,
        ),
      );
    });
    try {
      await _repository.upload(
        groupId: widget.groupId,
        type: widget.type,
        path: draft.path,
        originalName: draft.name,
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          _updatePending(
            pendingId,
            (item) => item.copyWith(progress: sent / total),
          );
        },
      );
      _updatePending(
        pendingId,
        (item) => item.copyWith(progress: 1, completed: true),
      );
      try {
        final items = await _repository.list(widget.groupId, widget.type);
        if (mounted) {
          setState(() {
            _items = items;
            _pending.removeWhere((item) => item.id == pendingId);
          });
        }
      } catch (_) {
        // The upload is already committed. Keep its local preview visible
        // until pull-to-refresh can replace it with the server resource.
      }
      if (mounted) _message('上传成功');
    } catch (error) {
      _updatePending(pendingId, (item) => item.copyWith(failed: true));
      if (mounted) _message('上传失败：$error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<GroupResourceUploadDraft?> _pickNative(
    GroupResourceUploadKind kind,
  ) async {
    String? path;
    String? name;
    int size = 0;
    if (_isAlbum && kind == GroupResourceUploadKind.photo) {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 2560,
        maxHeight: 2560,
      );
      if (image == null) return null;
      path = image.path;
      name = image.name;
      size = await image.length();
      if (size > 5 * 1024 * 1024) {
        _message('照片不能超过5MB');
        return null;
      }
    } else if (_isAlbum && kind == GroupResourceUploadKind.video) {
      final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (video == null) return null;
      path = video.path;
      name = video.name;
      try {
        await validateVideoFile(path);
      } catch (error) {
        _message(error.toString().replaceFirst('Exception: ', ''));
        return null;
      }
      size = await video.length();
    } else {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
      final file = result?.files.singleOrNull;
      if (file == null || file.path == null) return null;
      path = file.path;
      name = file.name;
      size = file.size;
      if (size > 300 * 1024 * 1024) {
        _message('单个文件不能超过300MB');
        return null;
      }
    }
    return GroupResourceUploadDraft(
      path: path!,
      name: name,
      size: size,
      kind: kind,
    );
  }

  void _updatePending(
    String id,
    _PendingGroupResource Function(_PendingGroupResource item) update,
  ) {
    if (!mounted) return;
    final index = _pending.indexWhere((item) => item.id == id);
    if (index < 0) return;
    setState(() => _pending[index] = update(_pending[index]));
  }

  Future<void> _delete(GroupResource item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isAlbum ? (item.isVideo ? '删除视频' : '删除照片') : '删除文件'),
        content: Text('确定删除“${item.originalName}”吗？此操作会同时删除服务器文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.delete(item.id);
      await _load();
    } catch (error) {
      if (mounted) _message('删除失败：$error');
    }
  }

  Future<void> _openFile(GroupResource item) async {
    final url = _repository.downloadUrl(item.id);
    if (item.isVideo) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              AppVideoPlayerPage(source: url, fileName: item.originalName),
        ),
      );
      return;
    }
    try {
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory('${root.path}/group_files/${widget.groupId}');
      await directory.create(recursive: true);
      final safeName = item.originalName.replaceAll(
        RegExp(r'[/\\:*?"<>|]'),
        '_',
      );
      final path = '${directory.path}/$safeName';
      await HttpUtil().downloadFile(
        url,
        path,
        onReceiveProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (mounted) _message('已下载到应用本地：$path');
    } catch (error) {
      if (mounted) _message('下载失败：$error');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _save(GroupResource item) async {
    final url = _repository.downloadUrl(item.id);
    setState(() => _progress = 0);
    try {
      if (item.isImage) {
        await const ChatMediaSaver().saveImage(
          source: url,
          fileName: item.originalName,
        );
        if (mounted) _message('照片已保存到系统相册');
      } else if (item.isVideo) {
        await const ChatMediaSaver().saveVideo(
          source: url,
          fileName: item.originalName,
        );
        if (mounted) _message('视频已保存到系统相册');
      } else {
        final saved = await const ChatFileSaver().save(
          source: url,
          fileName: item.originalName,
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          beforeChoosingLocation: () async {
            if (mounted) setState(() => _progress = null);
          },
        );
        if (mounted) _message(saved ? '文件保存成功' : '已取消保存');
      }
    } catch (error) {
      if (mounted) _message('保存失败：$error');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  Future<void> _showResourceActions(GroupResource item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: ValueKey('save_group_resource_${item.id}'),
              leading: const Icon(Icons.download_rounded),
              title: Text(
                item.type == GroupResourceType.file ? '保存文件' : '保存到本地',
              ),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            if (item.canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'save') await _save(item);
    if (action == 'delete') await _delete(item);
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value), duration: const Duration(seconds: 2)),
  );
  String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(1)} KB';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(_isAlbum ? '群相册' : '群文件'),
        actions: [
          IconButton(
            onPressed: _uploading ? null : _chooseAndUpload,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress != null) LinearProgressIndicator(value: _progress),
          Expanded(
            child: _loading && _pending.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty && _pending.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isAlbum
                              ? Icons.photo_library_outlined
                              : Icons.folder_open,
                          size: 58,
                          color: Colors.grey[350],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isAlbum ? '暂无群照片或视频' : '暂无群文件',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _isAlbum ? _buildAlbum() : _buildFiles(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploading ? null : _chooseAndUpload,
        icon: Icon(_isAlbum ? Icons.add_to_photos_outlined : Icons.upload_file),
        label: Text(_isAlbum ? '上传照片或视频' : '上传文件'),
      ),
    );
  }

  Widget _buildAlbum() => GridView.builder(
    padding: const EdgeInsets.all(10),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 5,
      mainAxisSpacing: 5,
    ),
    itemCount: _pending.length + _items.length,
    itemBuilder: (context, index) {
      if (index < _pending.length) {
        return _buildPendingAlbumItem(_pending[index]);
      }
      final item = _items[index - _pending.length];
      final url = _repository.downloadUrl(item.id);
      return Stack(
        fit: StackFit.expand,
        children: [
          if (item.isVideo)
            LayoutBuilder(
              builder: (context, constraints) => AppVideoPreview(
                key: ValueKey('group_album_video_${item.id}'),
                source: url,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fileName: item.originalName,
                autoCacheRemote: true,
                onLongPress: () => _showResourceActions(item),
              ),
            )
          else
            GestureDetector(
              onTap: () => showFullscreenImage(
                context,
                imageProvider: AppImageCache.provider(url),
                onSave: () => _save(item),
              ),
              onLongPress: () => _showResourceActions(item),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  cacheManager: AppImageCache.manager,
                  imageUrl: url,
                  cacheKey: AppImageCache.cacheKey(url),
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => ColoredBox(
                    color: context.appSurface,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          if (item.canDelete)
            Positioned(
              top: 3,
              right: 3,
              child: IconButton.filled(
                onPressed: () => _delete(item),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  minimumSize: const Size(28, 28),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 17,
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _buildPendingAlbumItem(_PendingGroupResource item) {
    final progress = item.progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.isVideo)
            AppVideoPreview(
              key: ValueKey('pending_group_video_${item.id}'),
              source: item.path,
              isLocal: true,
              fileName: item.name,
              uploadProgress: item.failed ? null : progress,
              uploadFailed: item.failed,
            )
          else
            Image.file(
              File(item.path),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => ColoredBox(
                color: context.appSurface,
                child: const Icon(Icons.image_outlined),
              ),
            ),
          if (!item.isVideo)
            ColoredBox(
              color: const Color(0x55000000),
              child: Center(
                child: item.failed
                    ? const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 34,
                      )
                    : _UploadProgressBadge(progress: progress),
              ),
            ),
          if (item.failed)
            Positioned(
              right: 4,
              top: 4,
              child: IconButton.filled(
                key: ValueKey('remove_pending_group_resource_${item.id}'),
                onPressed: () => setState(() => _pending.remove(item)),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  minimumSize: const Size(28, 28),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.close, size: 17),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFiles() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
    itemCount: _pending.length + _items.length,
    separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
    itemBuilder: (context, index) {
      if (index < _pending.length) {
        return _buildPendingFileItem(_pending[index]);
      }
      final item = _items[index - _pending.length];
      return ListTile(
        tileColor: context.appSurface,
        leading: _buildServerFilePreview(item),
        title: Text(
          item.originalName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_size(item.fileSize)} · ${item.uploaderId} · ${DateFormat('MM-dd HH:mm').format(item.createdAt)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          key: ValueKey('group_resource_actions_${item.id}'),
          onPressed: () => _showResourceActions(item),
          icon: const Icon(Icons.more_horiz),
        ),
        onTap: () => _openFile(item),
        onLongPress: () => _showResourceActions(item),
      );
    },
  );

  Widget _buildPendingFileItem(_PendingGroupResource item) {
    final progress = item.progress.clamp(0.0, 1.0);
    return ListTile(
      key: ValueKey('pending_group_file_${item.id}'),
      tileColor: context.appSurface,
      leading: _buildLocalFilePreview(item),
      title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        item.failed
            ? '上传失败'
            : item.completed
            ? '已上传，正在刷新列表'
            : '${_size(item.size)} · 上传中 ${(progress * 100).round()}%',
        style: item.failed ? const TextStyle(color: Colors.red) : null,
      ),
      trailing: item.failed
          ? IconButton(
              onPressed: () => setState(() => _pending.remove(item)),
              icon: const Icon(Icons.close),
            )
          : _UploadProgressBadge(progress: progress, size: 40),
    );
  }

  Widget _buildLocalFilePreview(_PendingGroupResource item) {
    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(item.path),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fileIcon(item.isVideo),
        ),
      );
    }
    if (item.isVideo) {
      return AppVideoPreview(
        source: item.path,
        isLocal: true,
        width: 48,
        height: 48,
        fileName: item.name,
        uploadProgress: item.failed ? null : item.progress,
        uploadFailed: item.failed,
      );
    }
    return _fileIcon(false);
  }

  Widget _buildServerFilePreview(GroupResource item) {
    final url = _repository.downloadUrl(item.id);
    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          cacheManager: AppImageCache.manager,
          imageUrl: url,
          cacheKey: AppImageCache.cacheKey(url),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => _fileIcon(false),
        ),
      );
    }
    if (item.isVideo) {
      return AppVideoPreview(
        source: url,
        width: 48,
        height: 48,
        fileName: item.originalName,
        autoCacheRemote: true,
        onLongPress: () => _showResourceActions(item),
      );
    }
    return _fileIcon(false);
  }

  Widget _fileIcon(bool video) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: video ? Colors.purple[50] : Colors.amber[50],
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(
      video ? Icons.play_circle_outline : Icons.insert_drive_file_outlined,
      color: video ? Colors.purple : Colors.amber[800],
    ),
  );
}

class _UploadProgressBadge extends StatelessWidget {
  const _UploadProgressBadge({required this.progress, this.size = 54});

  final double progress;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0x99000000),
      shape: BoxShape.circle,
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: size - 10,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            color: Colors.white,
            backgroundColor: Colors.white24,
          ),
        ),
        Text(
          '${(progress * 100).round()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _PendingGroupResource {
  const _PendingGroupResource({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.kind,
    required this.progress,
    this.failed = false,
    this.completed = false,
  });

  final String id;
  final String path;
  final String name;
  final int size;
  final GroupResourceUploadKind kind;
  final double progress;
  final bool failed;
  final bool completed;

  bool get isVideo =>
      kind == GroupResourceUploadKind.video || isVideoPath(path);
  bool get isImage {
    if (kind == GroupResourceUploadKind.photo) return true;
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  _PendingGroupResource copyWith({
    double? progress,
    bool? failed,
    bool? completed,
  }) => _PendingGroupResource(
    id: id,
    path: path,
    name: name,
    size: size,
    kind: kind,
    progress: progress ?? this.progress,
    failed: failed ?? this.failed,
    completed: completed ?? this.completed,
  );
}
