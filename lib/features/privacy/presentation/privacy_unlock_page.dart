import 'package:flutter/material.dart';

import '../application/privacy_settings_service.dart';
import 'gesture_pattern_pad.dart';

class PrivacyUnlockPage extends StatefulWidget {
  const PrivacyUnlockPage({
    super.key,
    required this.onRejected,
    this.onUnlocked,
    this.verifyGesture,
  });

  final Future<void> Function() onRejected;
  final Future<void> Function()? onUnlocked;
  final bool Function(List<int> pattern)? verifyGesture;

  @override
  State<PrivacyUnlockPage> createState() => _PrivacyUnlockPageState();
}

class _PrivacyUnlockPageState extends State<PrivacyUnlockPage> {
  var _checking = false;

  Future<void> _verify(List<int> pattern) async {
    if (_checking) return;
    _checking = true;
    final verified =
        widget.verifyGesture?.call(pattern) ??
        PrivacySettingsService.instance.verifyGesture(pattern);
    if (verified) {
      if (widget.onUnlocked != null) {
        await widget.onUnlocked!();
      } else if (mounted) {
        Navigator.pop(context, true);
      }
      return;
    }
    await widget.onRejected();
    if (mounted) {
      setState(() => _checking = false);
    } else {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 70, 40, 24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.shield_moon_outlined,
                    size: 34,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '隐私模式已锁定',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '绘制手势以进入全信',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 42),
                GesturePatternPad(enabled: !_checking, onCompleted: _verify),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
