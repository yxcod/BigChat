import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_context.dart';
import '../../../shared/widgets/app_back_button.dart';

class UserReportPage extends StatefulWidget {
  const UserReportPage({
    super.key,
    required this.userName,
    required this.displayName,
  });

  final String userName;
  final String displayName;

  @override
  State<UserReportPage> createState() => _UserReportPageState();
}

class _UserReportPageState extends State<UserReportPage> {
  static const _reasons = <String>[
    '色情低俗',
    '欺诈骗钱',
    '骚扰辱骂',
    '违法违规',
    '冒充他人',
    '其他',
  ];

  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedReason;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择举报原因')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('举报功能暂未开放'),
        content: const Text('当前仅完成界面展示，本次填写的内容不会上传或保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.displayName.trim().isEmpty
        ? widget.userName
        : widget.displayName.trim();
    final initial = displayName.characters.isEmpty
        ? '?'
        : displayName.characters.first;
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('举报用户'),
        centerTitle: true,
        backgroundColor: context.appSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ReportCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: const Color(0x1F07C160),
                child: Text(
                  initial,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
              title: Text(
                displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('账号：${widget.userName}'),
            ),
          ),
          const SizedBox(height: 16),
          Text('请选择举报原因', style: TextStyle(color: context.appTextSecondary)),
          const SizedBox(height: 8),
          _ReportCard(
            child: RadioGroup<String>(
              groupValue: _selectedReason,
              onChanged: (value) => setState(() => _selectedReason = value),
              child: Column(
                children: [
                  for (var index = 0; index < _reasons.length; index++) ...[
                    RadioListTile<String>(
                      key: Key('report_reason_$index'),
                      value: _reasons[index],
                      activeColor: AppColors.primary,
                      title: Text(_reasons[index]),
                    ),
                    if (index != _reasons.length - 1)
                      Divider(height: 1, indent: 16, color: context.appDivider),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('补充说明（选填）', style: TextStyle(color: context.appTextSecondary)),
          const SizedBox(height: 8),
          _ReportCard(
            child: TextField(
              key: const Key('report_description_field'),
              controller: _descriptionController,
              minLines: 4,
              maxLines: 6,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: '请描述具体情况',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('report_submit_button'),
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('提交举报'),
          ),
          const SizedBox(height: 10),
          Text(
            '举报功能目前仅提供界面预览，暂不会提交任何数据。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
