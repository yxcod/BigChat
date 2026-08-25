import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/app_back_button.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/cache/app_image_cache.dart';
import '../../../shared/widgets/app_video_player.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../utils/http.dart';
import '../../../app/theme/app_theme_context.dart';
import '../data/group_resource_repository.dart';
import '../domain/group_resource.dart';

class GroupResourceListPage extends StatefulWidget {
  const GroupResourceListPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.type,
  });
  final int groupId;
  final String groupName;
  final GroupResourceType type;
  @override
  State<GroupResourceListPage> createState() => _GroupResourceListPageState();
}

class _GroupResourceListPageState extends State<GroupResourceListPage> {
  final GroupResourceRepository _repository = GroupResourceRepository();
  List<GroupResource> _items = const [];
  bool _loading = true;
  bool _uploading = false;
  double? _progress;

  bool get _isAlbum => widget.type == GroupResourceType.photo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final items = await _repository.list(widget.groupId, widget.type);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) _message('加载失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    String? path;
    String? name;
    int size = 0;
    if (_isAlbum) {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 2560,
        maxHeight: 2560,
      );
      if (image == null) return;
      path = image.path;
      name = image.name;
      size = await image.length();
      if (size > 5 * 1024 * 1024) {
        _message('照片不能超过5MB');
        return;
      }
    } else {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );
      final file = result?.files.singleOrNull;
      if (file == null || file.path == null) return;
      path = file.path;
      name = file.name;
      size = file.size;
      if (size > 300 * 1024 * 1024) {
        _message('单个文件不能超过300MB');
        return;
      }
    }
    setState(() {
      _uploading = true;
      _progress = null;
    });
    try {
      await _repository.upload(
        groupId: widget.groupId,
        type: widget.type,
        path: path!,
        originalName: name,
        onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => _progress = sent / total);
        },
      );
      await _load();
      if (mounted) _message('上传成功');
    } catch (error) {
      if (mounted) _message('上传失败：$error');
    } finally {
      if (mounted)
        setState(() {
          _uploading = false;
          _progress = null;
        });
    }
  }

  Future<void> _delete(GroupResource item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isAlbum ? '删除照片' : '删除文件'),
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
    if (item.mimeType.startsWith('video/')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AppVideoPlayerPage(source: url),
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
          if (mounted && total > 0)
            setState(() => _progress = received / total);
        },
      );
      if (mounted) _message('已下载到应用本地：$path');
    } catch (error) {
      if (mounted) _message('下载失败：$error');
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  void _message(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
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
            onPressed: _uploading ? null : _pickAndUpload,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_uploading || _progress != null)
            LinearProgressIndicator(value: _progress),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
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
                          _isAlbum ? '暂无群照片' : '暂无群文件',
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
        onPressed: _uploading ? null : _pickAndUpload,
        icon: Icon(
          _isAlbum ? Icons.add_photo_alternate_outlined : Icons.upload_file,
        ),
        label: Text(_isAlbum ? '上传照片' : '上传文件'),
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
    itemCount: _items.length,
    itemBuilder: (context, index) {
      final item = _items[index];
      final url = _repository.downloadUrl(item.id);
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () => showFullscreenImage(
              context,
              imageProvider: AppImageCache.provider(url),
            ),
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

  Widget _buildFiles() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
    itemCount: _items.length,
    separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
    itemBuilder: (context, index) {
      final item = _items[index];
      return ListTile(
        tileColor: context.appSurface,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: item.mimeType.startsWith('video/')
                ? Colors.purple[50]
                : Colors.amber[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            item.mimeType.startsWith('video/')
                ? Icons.play_circle_outline
                : Icons.insert_drive_file_outlined,
            color: item.mimeType.startsWith('video/')
                ? Colors.purple
                : Colors.amber[800],
          ),
        ),
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
        trailing: item.canDelete
            ? IconButton(
                onPressed: () => _delete(item),
                icon: const Icon(Icons.delete_outline),
              )
            : const Icon(Icons.download_outlined),
        onTap: () => _openFile(item),
      );
    },
  );
}
