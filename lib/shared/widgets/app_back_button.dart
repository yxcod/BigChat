import 'package:flutter/material.dart';

/// 项目内统一的 iOS 风格返回按钮。
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed, this.color = Colors.black});

  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(Icons.arrow_back_ios_new, color: color, size: 24),
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}
