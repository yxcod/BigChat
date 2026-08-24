import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class EditFriendRemarkPage extends StatefulWidget {
  const EditFriendRemarkPage({super.key, required this.initialRemark});

  final String initialRemark;

  @override
  State<EditFriendRemarkPage> createState() => _EditFriendRemarkPageState();
}

class _EditFriendRemarkPageState extends State<EditFriendRemarkPage> {
  static const int _maxLength = 30;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialRemark);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _complete() {
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 76,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            '取消',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
          ),
        ),
        title: const Text('设置备注'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              key: const Key('friend_remark_complete_button'),
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
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            key: const Key('friend_remark_field'),
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            maxLength: _maxLength,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _complete(),
            decoration: const InputDecoration(
              hintText: '请输入备注',
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
