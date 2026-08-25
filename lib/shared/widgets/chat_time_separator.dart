import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../model/messageModel.dart';

bool shouldShowChatTimeSeparator({
  required Message current,
  Message? previous,
  Duration threshold = const Duration(minutes: 5),
}) {
  if (previous == null) return true;
  final currentTime = DateTime.fromMillisecondsSinceEpoch(current.timestamp);
  final previousTime = DateTime.fromMillisecondsSinceEpoch(previous.timestamp);
  final changedDay =
      currentTime.year != previousTime.year ||
      currentTime.month != previousTime.month ||
      currentTime.day != previousTime.day;
  return changedDay || currentTime.difference(previousTime).abs() >= threshold;
}

class ChatTimeSeparator extends StatelessWidget {
  const ChatTimeSeparator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
