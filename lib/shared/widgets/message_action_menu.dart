import 'package:flutter/material.dart';

enum MessageActionType { copy, speaker, transcription, save, delete, quote }

class MessageActionItem {
  const MessageActionItem({
    required this.type,
    required this.label,
    required this.icon,
  });

  final MessageActionType type;
  final String label;
  final IconData icon;
}

Future<MessageActionType?> showMessageActionMenu({
  required BuildContext context,
  required Offset anchor,
  required List<MessageActionItem> actions,
}) {
  return showGeneralDialog<MessageActionType>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭消息操作菜单',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final screen = MediaQuery.sizeOf(dialogContext);
      final menuWidth = (screen.width - 24).clamp(0.0, 326.0);
      final rows = (actions.length / 4).ceil();
      final menuHeight = rows * 78.0 + 18;
      final maxLeft = screen.width - menuWidth - 12;
      final left = (anchor.dx - menuWidth / 2).clamp(12.0, maxLeft);
      var top = anchor.dy - menuHeight - 14;
      if (top < MediaQuery.paddingOf(dialogContext).top + 8) {
        top = anchor.dy + 14;
      }
      top = top.clamp(8.0, screen.height - menuHeight - 8);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(dialogContext),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: Material(
              color: const Color(0xEE3E3E3E),
              elevation: 10,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
                child: Wrap(
                  runSpacing: 2,
                  children: actions.map((action) {
                    return SizedBox(
                      width: (menuWidth - 16) / 4,
                      height: 78,
                      child: InkWell(
                        key: ValueKey('message_action_${action.type.name}'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(dialogContext, action.type),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(action.icon, color: Colors.white, size: 25),
                            const SizedBox(height: 7),
                            Text(
                              action.label,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(animation),
          child: child,
        ),
      );
    },
  );
}
