import 'package:flutter/material.dart';

import '../../shared/pages/app_text_editor_page.dart';

class EditFriendRemarkPage extends StatelessWidget {
  const EditFriendRemarkPage({super.key, required this.initialRemark});

  final String initialRemark;

  @override
  Widget build(BuildContext context) {
    return AppTextEditorPage(
      title: '设置备注',
      initialValue: initialRemark,
      hintText: '请输入备注',
      maxLength: 30,
      fieldKey: const Key('friend_remark_field'),
      saveButtonKey: const Key('friend_remark_complete_button'),
    );
  }
}
