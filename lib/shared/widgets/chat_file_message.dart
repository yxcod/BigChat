import 'package:flutter/material.dart';

import '../../app/theme/app_theme_context.dart';
import '../../core/media/chat_file.dart';

class ChatFileMessage extends StatelessWidget {
  const ChatFileMessage({
    super.key,
    required this.payload,
    this.uploadProgress,
    this.uploadFailed = false,
  });

  final ChatFilePayload payload;
  final double? uploadProgress;
  final bool uploadFailed;

  @override
  Widget build(BuildContext context) {
    final progress = uploadProgress?.clamp(0.0, 1.0);
    final uploading = progress != null && progress < 1 && !uploadFailed;
    final percent = ((progress ?? 0) * 100).round();
    return Container(
      width: 238,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appDivider),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.insert_drive_file_rounded,
              color: Color(0xFF3989D8),
              size: 29,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payload.originalName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                if (uploadFailed)
                  const Text(
                    '发送失败',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  )
                else if (uploading) ...[
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '正在发送 $percent%',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ] else
                  Text(
                    formatFileSize(payload.sizeBytes),
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 12,
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
