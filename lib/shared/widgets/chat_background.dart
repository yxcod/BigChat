import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/cache/app_image_cache.dart';
import '../../features/settings/data/app_settings_repository.dart';
import '../../utils/gloabl.dart';

class ChatBackground extends StatefulWidget {
  const ChatBackground({super.key, required this.child, this.repository});

  final Widget child;
  final AppSettingsRepository? repository;

  @override
  State<ChatBackground> createState() => _ChatBackgroundState();
}

class _ChatBackgroundState extends State<ChatBackground> {
  static const _defaultBackgroundUrl =
      'https://images.unsplash.com/photo-1518837695005-2083093ee35b?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80';

  String _localPath = '';

  @override
  void initState() {
    super.initState();
    _loadBackground();
  }

  Future<void> _loadBackground() async {
    final repository =
        widget.repository ??
        AppSettingsRepository(ownerId: GlobalUtil().userName ?? '');
    final configuredPath = (await repository.load()).chatBackgroundPath;
    final canUseLocalFile =
        !kIsWeb &&
        configuredPath.isNotEmpty &&
        await File(configuredPath).exists();
    if (!mounted || !canUseLocalFile) return;
    setState(() => _localPath = configuredPath);
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object> provider = _localPath.isNotEmpty
        ? FileImage(File(_localPath))
        : AppImageCache.provider(_defaultBackgroundUrl);
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: provider,
          fit: BoxFit.cover,
          opacity: _localPath.isEmpty ? 0.2 : 0.32,
        ),
      ),
      child: widget.child,
    );
  }
}
