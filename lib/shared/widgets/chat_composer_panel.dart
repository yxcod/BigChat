import 'package:flutter/material.dart';

import '../../app/theme/app_theme_context.dart';

/// Keeps the chat editor clear of the iPhone home indicator while ensuring
/// the expanded actions panel remains directly below the editor.
class ChatComposerPanel extends StatelessWidget {
  const ChatComposerPanel({
    super.key,
    required this.composer,
    required this.moreActionsVisible,
    required this.moreActions,
  });

  final Widget composer;
  final bool moreActionsVisible;
  final Widget moreActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: context.appSurface,
          child: SafeArea(
            top: false,
            bottom: !moreActionsVisible,
            minimum: EdgeInsets.only(bottom: moreActionsVisible ? 0 : 10),
            child: composer,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: moreActionsVisible ? moreActions : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
