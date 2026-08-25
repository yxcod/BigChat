import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';

/// 全局统一的单字段文本编辑页面。
///
/// 删除、退出等确认操作仍使用弹窗；凡是需要用户输入文本的设置都应进入
/// 此类独立页面，避免键盘与弹窗叠加导致的布局和焦点问题。
class AppTextEditorPage extends StatefulWidget {
  const AppTextEditorPage({
    super.key,
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.maxLength,
    this.maxLines = 1,
    this.allowEmpty = true,
    this.emptyMessage = '请输入内容',
    this.saveText = '保存',
    this.cancelText = '取消',
    this.fieldKey,
    this.saveButtonKey,
  });

  final String title;
  final String initialValue;
  final String hintText;
  final int maxLength;
  final int maxLines;
  final bool allowEmpty;
  final String emptyMessage;
  final String saveText;
  final String cancelText;
  final Key? fieldKey;
  final Key? saveButtonKey;

  @override
  State<AppTextEditorPage> createState() => _AppTextEditorPageState();
}

class _AppTextEditorPageState extends State<AppTextEditorPage> {
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

  void _save() {
    final value = _controller.text.trim();
    if (!widget.allowEmpty && value.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.emptyMessage)));
      return;
    }
    Navigator.pop(context, value);
  }

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
        leadingWidth: 72,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            widget.cancelText,
            style: TextStyle(color: context.appTextPrimary, fontSize: 16),
          ),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: widget.saveButtonKey,
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(50, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: Text(widget.saveText),
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
            key: widget.fieldKey,
            controller: _controller,
            autofocus: true,
            maxLength: widget.maxLength,
            minLines: widget.maxLines > 1 ? widget.maxLines : 1,
            maxLines: widget.maxLines,
            textInputAction: widget.maxLines == 1
                ? TextInputAction.done
                : TextInputAction.newline,
            onSubmitted: widget.maxLines == 1 ? (_) => _save() : null,
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
