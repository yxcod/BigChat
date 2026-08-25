import 'package:flutter/material.dart';

import '../../app/theme/app_theme_context.dart';

const chatChromeBackgroundColor = Colors.white;
const chatChromeDividerColor = Color(0xFFE8E8E8);

class ChatMoreActionsSheet extends StatelessWidget {
  const ChatMoreActionsSheet({super.key, this.onSelected});

  final ValueChanged<ChatMoreActionType>? onSelected;

  @override
  Widget build(BuildContext context) {
    final actions = <_ChatMoreAction>[
      _ChatMoreAction(
        ChatMoreActionType.gallery,
        '照片/视频',
        Icons.photo_outlined,
      ),
      _ChatMoreAction(
        ChatMoreActionType.capture,
        '拍摄',
        Icons.camera_alt_outlined,
      ),
      _ChatMoreAction(
        ChatMoreActionType.location,
        '位置',
        Icons.location_on_outlined,
      ),
      _ChatMoreAction(ChatMoreActionType.file, '文件', Icons.folder_outlined),
    ];

    return Material(
      color: context.appPageBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: context.appDivider),
          SafeArea(
            top: false,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent: 112,
                crossAxisSpacing: 12,
                mainAxisSpacing: 8,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    final callback = onSelected;
                    if (callback != null) {
                      callback(action.type);
                    } else {
                      Navigator.pop(context, action.type);
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: context.appSurface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          action.icon,
                          size: 30,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMoreAction {
  const _ChatMoreAction(this.type, this.label, this.icon);

  final ChatMoreActionType type;
  final String label;
  final IconData icon;
}

enum ChatMoreActionType { gallery, capture, location, file }
