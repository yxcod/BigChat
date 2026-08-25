import 'package:flutter/material.dart';

const String userAgreementContent =
    '此软件只供内部学习交流使用，不用于任何商业用途，若出了任何问题请去未个几找几个姓王和姓张的兄弟，他们会替我解释一切。';

Future<void> showUserAgreementDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('user_agreement_dialog'),
      title: const Text('用户协议'),
      content: const Text(userAgreementContent),
      actions: [
        TextButton(
          key: const Key('user_agreement_confirm_button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('我知道了'),
        ),
      ],
    ),
  );
}
