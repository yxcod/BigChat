import 'package:flutter/material.dart';

import '../../core/media/chat_file.dart';
import '../../core/media/chat_file_saver.dart';

Future<void> saveChatFileWithFeedback(
  BuildContext context, {
  required ChatFilePayload payload,
  required String source,
}) async {
  final progress = ValueNotifier<double?>(null);
  OverlayEntry? progressEntry;

  void removeProgress() {
    progressEntry?.remove();
    progressEntry = null;
  }

  progressEntry = OverlayEntry(
    builder: (overlayContext) => Stack(
      children: [
        const Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Color(0x55000000)),
        ),
        Center(
          child: Material(
            color: Theme.of(overlayContext).colorScheme.surface,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 230,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: ValueListenableBuilder<double?>(
                  valueListenable: progress,
                  builder: (context, value, child) {
                    final percent = value == null
                        ? null
                        : (value * 100).round();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(value: value),
                        const SizedBox(height: 14),
                        Text(
                          percent == null ? '正在接收文件…' : '正在接收文件 $percent%',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          payload.originalName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(progressEntry!);

  try {
    final saved = await const ChatFileSaver().save(
      source: source,
      fileName: payload.originalName,
      onProgress: (value) => progress.value = value,
      beforeChoosingLocation: () async => removeProgress(),
    );
    if (context.mounted && saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件已保存'), duration: Duration(seconds: 2)),
      );
    }
  } catch (_) {
    removeProgress();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文件保存失败，请检查网络后重试'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  } finally {
    removeProgress();
    progress.dispose();
  }
}
