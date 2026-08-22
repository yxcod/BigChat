import 'dart:async';

import 'package:flutter/material.dart';

class ChatScrollUtil {
  const ChatScrollUtil._();

  /// Repeatedly aligns a lazily built chat list with its bottom while message
  /// bubbles and images finish layout.
  static void scheduleJumpToBottom({
    required ScrollController controller,
    required bool Function() isActive,
    VoidCallback? onComplete,
    Duration settleDuration = const Duration(milliseconds: 700),
    Duration retryInterval = const Duration(milliseconds: 32),
  }) {
    final deadline = DateTime.now().add(settleDuration);

    void schedulePass() {
      if (!isActive()) {
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!isActive()) {
          return;
        }

        if (controller.hasClients) {
          final target = controller.position.maxScrollExtent;
          if ((controller.position.pixels - target).abs() > 0.5) {
            controller.jumpTo(target);
          }
        }

        if (DateTime.now().isBefore(deadline)) {
          Timer(retryInterval, schedulePass);
        } else {
          onComplete?.call();
        }
      });
    }

    schedulePass();
  }
}
