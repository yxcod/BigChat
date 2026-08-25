import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Shared input row for private and group conversations.
///
/// The recording gesture still belongs to [editor]; this toolbar only keeps
/// the surrounding actions and spacing consistent between both chat pages.
class ChatComposerToolbar extends StatelessWidget {
  const ChatComposerToolbar({
    super.key,
    required this.editor,
    required this.isComposing,
    required this.isUploadingAudio,
    required this.isUploadingMedia,
    required this.onVoiceHint,
    required this.onMedia,
    required this.onMore,
    required this.onSend,
    this.mediaProgress,
  });

  final Widget editor;
  final bool isComposing;
  final bool isUploadingAudio;
  final bool isUploadingMedia;
  final double? mediaProgress;
  final VoidCallback onVoiceHint;
  final VoidCallback onMedia;
  final VoidCallback onMore;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ComposerActionButton(
          key: const ValueKey('chat_voice_hint_button'),
          tooltip: '语音输入',
          icon: Icons.mic_none_rounded,
          onPressed: onVoiceHint,
        ),
        const SizedBox(width: 2),
        Expanded(child: editor),
        if (isUploadingAudio)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        const SizedBox(width: 2),
        _ComposerActionButton(
          key: const ValueKey('chat_media_button'),
          tooltip: '发送图片或视频',
          icon: Icons.camera_alt_outlined,
          onPressed: isUploadingMedia ? null : onMedia,
          progress: isUploadingMedia ? mediaProgress : null,
          indeterminateProgress: isUploadingMedia && mediaProgress == null,
        ),
        const SizedBox(width: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: isComposing
              ? _ComposerActionButton(
                  key: const ValueKey('chat_send_button'),
                  tooltip: '发送',
                  icon: Icons.send_rounded,
                  color: AppColors.primary,
                  onPressed: onSend,
                )
              : _ComposerActionButton(
                  key: const ValueKey('chat_more_button'),
                  tooltip: '更多',
                  icon: Icons.add_circle_outline_rounded,
                  iconSize: 29,
                  onPressed: onMore,
                ),
        ),
      ],
    );
  }
}

class _ComposerActionButton extends StatelessWidget {
  const _ComposerActionButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFF25272A),
    this.iconSize = 25,
    this.progress,
    this.indeterminateProgress = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;
  final double iconSize;
  final double? progress;
  final bool indeterminateProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 42,
      child: IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: progress != null || indeterminateProgress
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  value: indeterminateProgress ? null : progress,
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Icon(icon, size: iconSize, color: color),
      ),
    );
  }
}
