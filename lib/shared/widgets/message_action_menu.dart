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

Rect? messageActionTargetRect(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize) {
    return null;
  }
  final origin = renderObject.localToGlobal(Offset.zero);
  return origin & renderObject.size;
}

Future<MessageActionType?> showMessageActionMenu({
  required BuildContext context,
  required Offset anchor,
  required List<MessageActionItem> actions,
  Rect? targetRect,
}) {
  return showGeneralDialog<MessageActionType>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭消息操作菜单',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final screen = MediaQuery.sizeOf(dialogContext);
      final columns = actions.length.clamp(1, 4);
      const itemWidth = 68.0;
      final menuWidth = (columns * itemWidth + 16).clamp(
        0.0,
        screen.width - 24,
      );
      final rows = (actions.length / 4).ceil();
      final menuHeight = rows * 64.0 + 16;
      final target =
          targetRect ?? Rect.fromCenter(center: anchor, width: 1, height: 1);
      final maxLeft = screen.width - menuWidth - 12;
      final left = (target.center.dx - menuWidth / 2).clamp(12.0, maxLeft);
      final safeTop = MediaQuery.paddingOf(dialogContext).top + 8;
      var top = target.top - menuHeight - 8;
      if (top < safeTop) {
        top = target.bottom + 8;
      }
      top = top.clamp(safeTop, screen.height - menuHeight - 8);
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
              key: const ValueKey('message_action_menu'),
              color: const Color(0xEE3E3E3E),
              elevation: 10,
              borderRadius: BorderRadius.circular(13),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Wrap(
                  runSpacing: 0,
                  children: actions.map((action) {
                    return SizedBox(
                      width: (menuWidth - 16) / columns,
                      height: 64,
                      child: InkWell(
                        key: ValueKey('message_action_${action.type.name}'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.pop(dialogContext, action.type),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(action.icon, color: Colors.white, size: 22),
                            const SizedBox(height: 4),
                            Text(
                              action.label,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.15,
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
