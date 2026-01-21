import 'package:flutter/material.dart';
import '../utils/messageUtil.dart';

class MessageUtilDemo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('提示框工具类演示'), backgroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 基础提示类型
            _buildSectionTitle('基础提示类型'),
            _buildButtonRow(
              '成功提示',
              () => MessageUtil.showSuccess(context, '操作成功完成！'),
            ),
            _buildButtonRow(
              '错误提示',
              () => MessageUtil.showError(context, '操作失败，请重试'),
            ),
            _buildButtonRow(
              '警告提示',
              () => MessageUtil.showWarning(context, '此操作有风险，请确认'),
            ),
            _buildButtonRow(
              '信息提示',
              () => MessageUtil.showInfo(context, '这是一条信息提示'),
            ),

            SizedBox(height: 24),

            // 对话框类型
            _buildSectionTitle('对话框类型'),
            _buildButtonRow('确认对话框', () async {
              bool? result = await MessageUtil.showConfirmDialog(
                context,
                title: '用户确认',
                content: '是否确认删除这个文件？',
              );
              if (result == true) {
                MessageUtil.showSuccess(context, '已确认删除');
              } else {
                MessageUtil.showInfo(context, '已取消操作');
              }
            }),
            _buildButtonRow('删除确认', () async {
              bool? result = await MessageUtil.showDeleteConfirm(
                context,
                title: '删除好友',
                content: '确定要删除这个好友吗？此操作无法撤销。',
              );
              if (result == true) {
                MessageUtil.showSuccess(context, '好友已删除');
              } else {
                MessageUtil.showInfo(context, '已取消删除');
              }
            }),
            _buildButtonRow('输入对话框', () async {
              String? result = await MessageUtil.showInputDialog(
                context,
                title: '修改备注',
                hintText: '请输入新的备注名',
                initialValue: '张三',
              );
              if (result != null && result.isNotEmpty) {
                MessageUtil.showSuccess(context, '备注已更新为: $result');
              }
            }),
            _buildButtonRow('选择对话框', () async {
              List<String> options = ['北京', '上海', '广州', '深圳'];
              int? result = await MessageUtil.showSelectDialog(
                context,
                title: '选择城市',
                options: options,
              );
              if (result != null) {
                MessageUtil.showSuccess(context, '选择了: ${options[result]}');
              }
            }),

            SizedBox(height: 24),

            // 便捷方法演示
            _buildSectionTitle('便捷方法演示'),
            _buildButtonRow(
              '扩展方法 - 成功',
              () => context.showSuccess('使用扩展方法显示成功'),
            ),
            _buildButtonRow('扩展方法 - 错误', () => context.showError('使用扩展方法显示错误')),
            _buildButtonRow('扩展方法 - 确认', () async {
              bool? result = await context.showConfirm('确定要执行此操作吗？');
              if (result == true) {
                context.showSuccess('操作已确认');
              }
            }),

            SizedBox(height: 24),

            // 自定义提示
            _buildSectionTitle('自定义提示'),
            _buildButtonRow(
              '自定义提示',
              () => MessageUtil.showCustom(
                context,
                '这是一个自定义提示',
                Icons.star,
                Colors.purple,
                duration: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildButtonRow(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: TextStyle(fontSize: 16)),
      ),
    );
  }
}

// 演示应用
class MessageUtilDemoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '提示框工具类演示',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MessageUtilDemo(),
    );
  }
}

// 使用说明：
// 1. 在其他文件中导入：import '../utils/message_util.dart';
// 2. 直接调用：MessageUtil.showSuccess(context, '操作成功');
// 3. 或使用扩展方法：context.showSuccess('操作成功');
