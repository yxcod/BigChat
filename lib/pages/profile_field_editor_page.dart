import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_theme_context.dart';

class ProfileFieldEditorPage extends StatefulWidget {
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
  State<ProfileFieldEditorPage> createState() => _ProfileFieldEditorPageState();
}

class _ProfileFieldEditorPageState extends State<ProfileFieldEditorPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue)
      ..selection = TextSelection.collapsed(offset: widget.initialValue.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.appSurface,
        surfaceTintColor: context.appSurface,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 76,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            '取消',
            style: TextStyle(color: context.appTextPrimary, fontSize: 16),
          ),
        ),
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('profile_field_complete_button'),
              onPressed: _complete,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(58, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('完成'),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5),
        ),
      ),
      body: ColoredBox(
        color: context.appSurface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const Key('profile_field_editor'),
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            maxLines: widget.maxLines,
            textInputAction: widget.maxLines == 1
                ? TextInputAction.done
                : TextInputAction.newline,
            onSubmitted: widget.maxLines == 1 ? (_) => _complete() : null,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(fontSize: 17),
          ),
        ),
      ),
    );
  }
}
