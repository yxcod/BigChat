import 'package:flutter/material.dart';

const chatChromeBackgroundColor = Color(0xFFF5F5F5);
const chatChromeDividerColor = Color(0xFFE0E0E0);

class ChatMoreActionsSheet extends StatelessWidget {
  const ChatMoreActionsSheet({super.key});

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
      _ChatMoreAction(
        ChatMoreActionType.voiceInput,
        '语音输入',
        Icons.mic_none_outlined,
      ),
      _ChatMoreAction(
        ChatMoreActionType.favorite,
        '收藏',
        Icons.inventory_2_outlined,
      ),
      _ChatMoreAction(
        ChatMoreActionType.contactCard,
        '个人名片',
        Icons.person_outline,
      ),
      _ChatMoreAction(ChatMoreActionType.file, '文件', Icons.folder_outlined),
      _ChatMoreAction(
        ChatMoreActionType.music,
        '音乐',
        Icons.music_note_outlined,
      ),
    ];

    return Material(
      color: chatChromeBackgroundColor,
      child: SafeArea(
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
              onTap: () => Navigator.pop(context, action.type),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(action.icon, size: 30, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            );
          },
        ),
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

enum ChatMoreActionType {
  gallery,
  capture,
  location,
  voiceInput,
  favorite,
  contactCard,
  file,
  music,
}
