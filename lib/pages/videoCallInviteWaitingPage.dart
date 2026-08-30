import 'package:flutter/material.dart';

import '../core/cache/app_image_cache.dart';
import '../features/calls/application/call_coordinator.dart';
import '../features/calls/domain/call_signal.dart';
import '../utils/gloabl.dart';

class VideoCallInviteWaitingPage extends StatelessWidget {
  const VideoCallInviteWaitingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final coordinator = CallCoordinator.instance;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final session = coordinator.activeSession.value;
        if (session?.isCaller == true) {
          coordinator.cancelOutgoing();
        } else {
          coordinator.rejectIncoming();
        }
      },
      child: ValueListenableBuilder<AppCallSession?>(
        valueListenable: coordinator.activeSession,
        builder: (context, session, _) {
          if (session == null) {
            return const Scaffold(backgroundColor: Colors.black);
          }
          return Scaffold(
            backgroundColor: const Color(0xFF101215),
            body: SafeArea(child: _CallLobbyBody(session: session)),
          );
        },
      ),
    );
  }
}

class _CallLobbyBody extends StatelessWidget {
  const _CallLobbyBody({required this.session});

  final AppCallSession session;

  @override
  Widget build(BuildContext context) {
    final signal = session.signal;
    final incoming = !session.isCaller;
    final title = signal.isGroup
        ? (signal.groupName.isEmpty ? '群视频通话' : signal.groupName)
        : _peerDisplayName(signal, incoming: incoming);
    final status = signal.isGroup
        ? (incoming ? '${signal.senderName} 邀请你加入群视频' : '正在邀请群成员…')
        : (incoming ? '邀请你进行视频通话' : '正在等待对方接听…');
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF25313B), Color(0xFF0A0C0F)],
            ),
          ),
        ),
        Column(
          children: [
            const Spacer(flex: 2),
            _CallAvatar(signal: signal, incoming: incoming, title: title),
            const SizedBox(height: 24),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              status,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const Spacer(flex: 3),
            if (incoming)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundCallAction(
                    label: '拒绝',
                    icon: Icons.call_end_rounded,
                    color: const Color(0xFFE94B4B),
                    onTap: CallCoordinator.instance.rejectIncoming,
                  ),
                  _RoundCallAction(
                    label: '接听',
                    icon: Icons.videocam_rounded,
                    color: const Color(0xFF25C26E),
                    onTap: CallCoordinator.instance.acceptIncoming,
                  ),
                ],
              )
            else
              _RoundCallAction(
                label: '取消',
                icon: Icons.call_end_rounded,
                color: const Color(0xFFE94B4B),
                onTap: CallCoordinator.instance.cancelOutgoing,
              ),
            const SizedBox(height: 54),
          ],
        ),
      ],
    );
  }

  String _peerDisplayName(AppCallSignal signal, {required bool incoming}) {
    if (incoming) return signal.senderName;
    final friend = GlobalUtil().getFriendInfoByUserName(signal.receiverId);
    return friend.remarks?.trim().isNotEmpty == true
        ? friend.remarks!.trim()
        : friend.nickName?.trim().isNotEmpty == true
        ? friend.nickName!.trim()
        : signal.receiverId;
  }
}

class _CallAvatar extends StatelessWidget {
  const _CallAvatar({
    required this.signal,
    required this.incoming,
    required this.title,
  });

  final AppCallSignal signal;
  final bool incoming;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (signal.isGroup) {
      return Container(
        width: 112,
        height: 112,
        decoration: const BoxDecoration(
          color: Color(0xFF344550),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.groups_rounded, color: Colors.white, size: 58),
      );
    }
    final userId = incoming ? signal.senderId : signal.receiverId;
    final initial = title.trim().isEmpty ? '?' : title.trim().characters.first;
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image(
        image: AppImageCache.provider(
          GlobalUtil().getImageURL(userId, 'head.jpg'),
        ),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ColoredBox(
          color: const Color(0xFF344550),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white, fontSize: 42),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundCallAction extends StatelessWidget {
  const _RoundCallAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 42,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }
}
