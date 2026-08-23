import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/app_settings.dart';

class SoundSelectionPage extends StatelessWidget {
  const SoundSelectionPage({super.key, required this.selectedSoundId});

  final String selectedSoundId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('消息提示音')),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: 12),
        itemCount: NotificationSound.values.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, indent: 16, color: Color(0xFFE5E5E5)),
        itemBuilder: (context, index) {
          final sound = NotificationSound.values[index];
          final selected = sound.id == selectedSoundId;
          return Material(
            color: Colors.white,
            child: ListTile(
              key: ValueKey('notification_sound_${sound.id}'),
              title: Text(sound.label),
              trailing: selected
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => Navigator.pop(context, sound.id),
            ),
          );
        },
      ),
    );
  }
}
