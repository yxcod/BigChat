import 'package:flutter/material.dart';

import '../shared/pages/app_text_editor_page.dart';

class MessageUtil {
  // 显示成功提示（绿色）
  static void showSuccess(BuildContext context, String message) {
    _showMessage(context, message, Icons.check_circle, Colors.green);
  }

  // 显示错误提示（红色）
  static void showError(BuildContext context, String message) {
    _showMessage(context, message, Icons.error, Colors.red);
  }

  // 显示警告提示（橙色）
  static void showWarning(BuildContext context, String message) {
    _showMessage(context, message, Icons.warning, Colors.orange);
  }

  // 显示信息提示（蓝色）
  static void showInfo(BuildContext context, String message) {
    _showMessage(context, message, Icons.info, Colors.blue);
  }

  // 显示自定义提示
  static void showCustom(
    BuildContext context,
    String message,
    IconData icon,
    Color color, {
    int duration = 2,
  }) {
    _showMessage(context, message, icon, color, duration: duration);
  }

  // 显示确认对话框
  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    String title = '确认操作',
    String content = '确定要执行此操作吗？',
    String confirmText = '确定',
    String cancelText = '取消',
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor ?? Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  // 显示删除确认对话框（红色确认按钮）
  static Future<bool?> showDeleteConfirm(
    BuildContext context, {
    String title = '删除确认',
    String content = '确定要删除吗？此操作无法撤销。',
    String confirmText = '删除',
    String cancelText = '取消',
  }) {
    return showConfirmDialog(
      context,
      title: title,
      content: content,
      confirmText: confirmText,
      cancelText: cancelText,
      confirmColor: Colors.red,
    );
  }

  // 显示输入对话框
  static Future<String?> showInputDialog(
    BuildContext context, {
    String title = '输入',
    String hintText = '请输入内容',
    String confirmText = '确定',
    String cancelText = '取消',
    int maxLines = 1,
    String? initialValue,
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AppTextEditorPage(
          title: title,
          initialValue: initialValue ?? '',
          hintText: hintText,
          maxLength: 500,
          maxLines: maxLines,
          saveText: confirmText,
          cancelText: cancelText,
        ),
      ),
    );
  }

  // 显示选择对话框
  static Future<int?> showSelectDialog(
    BuildContext context, {
    required String title,
    required List<String> options,
    String confirmText = '确定',
    String cancelText = '取消',
  }) {
    return showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.asMap().entries.map((entry) {
              int index = entry.key;
              String option = entry.value;

              return ListTile(
                title: Text(option),
                onTap: () => Navigator.of(context).pop(index),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(cancelText),
            ),
          ],
        );
      },
    );
  }

  // 内部方法：显示SnackBar
  static void _showMessage(
    BuildContext context,
    String message,
    IconData icon,
    Color color, {
    int duration = 2,
  }) {
    if (message.isEmpty) return;

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      duration: Duration(seconds: duration),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.all(16),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

// 便捷的扩展方法
extension MessageExtension on BuildContext {
  void showSuccess(String message) => MessageUtil.showSuccess(this, message);
  void showError(String message) => MessageUtil.showError(this, message);
  void showWarning(String message) => MessageUtil.showWarning(this, message);
  void showInfo(String message) => MessageUtil.showInfo(this, message);
  Future<bool?> showConfirm(String content, {String? title}) =>
      MessageUtil.showConfirmDialog(
        this,
        content: content,
        title: title ?? '确认操作',
      );
  Future<bool?> showDeleteConfirm(String content, {String? title}) =>
      MessageUtil.showDeleteConfirm(
        this,
        content: content,
        title: title ?? '删除确认',
      );
}
