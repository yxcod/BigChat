import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../application/app_notification_feedback_service.dart';
import '../domain/app_settings.dart';

class SoundSelectionPage extends StatelessWidget {
  const SoundSelectionPage({super.key, required this.selectedSoundId});

  final String selectedSoundId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(title: const Text('消息提示音')),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 12),
        itemCount: NotificationSound.values.length,
        separatorBuilder: (_, _) =>
            Divider(height: 1, indent: 16, color: context.appDivider),
        itemBuilder: (context, index) {
          final sound = NotificationSound.values[index];
          final selected = sound.id == selectedSoundId;
          return Material(
            color: context.appSurface,
            child: ListTile(
              key: ValueKey('notification_sound_${sound.id}'),
              title: Text(sound.label),
              trailing: selected
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                Navigator.pop(context, sound.id);
                unawaited(AppNotificationTonePlayer.play(sound.id));
              },
            ),
          );
        },
      ),
    );
  }
}
