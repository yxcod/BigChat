import 'package:flutter/material.dart';

import '../shared/pages/app_text_editor_page.dart';

class ProfileFieldEditorPage extends StatelessWidget {
  const ProfileFieldEditorPage({
    super.key,
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.maxLength,
    this.maxLines = 1,
  });

  final String title;
  final String initialValue;
  final String hintText;
  final int maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return AppTextEditorPage(
      title: title,
      initialValue: initialValue,
      hintText: hintText,
      maxLength: maxLength,
      maxLines: maxLines,
      fieldKey: const Key('profile_field_editor'),
      saveButtonKey: const Key('profile_field_complete_button'),
    );
  }
}
