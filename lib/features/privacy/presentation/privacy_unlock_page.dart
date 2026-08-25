import 'package:flutter/material.dart';

import '../application/privacy_settings_service.dart';
import 'calculator_decoy_page.dart';
import 'gesture_pattern_pad.dart';

class PrivacyUnlockPage extends StatefulWidget {
  const PrivacyUnlockPage({
    super.key,
    required this.onForceLogout,
    this.onUnlocked,
  });

  final Future<void> Function() onForceLogout;
  final Future<void> Function()? onUnlocked;

  @override
  State<PrivacyUnlockPage> createState() => _PrivacyUnlockPageState();
}

class _PrivacyUnlockPageState extends State<PrivacyUnlockPage> {
  var _attempts = 0;
  var _checking = false;
  String _hint = '绘制手势以进入全信';

  Future<void> _verify(List<int> pattern) async {
    if (_checking) return;
    _checking = true;
    if (PrivacySettingsService.instance.verifyGesture(pattern)) {
      if (widget.onUnlocked != null) {
        await widget.onUnlocked!();
      } else if (mounted) {
        Navigator.pop(context, true);
      }
      return;
    }
    _attempts++;
    if (_attempts >= 3) {
      await widget.onForceLogout();
      return;
    }
    if (mounted) {
      setState(() => _hint = '手势错误，剩余 ${3 - _attempts} 次机会');
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const CalculatorDecoyPage()),
      );
    }
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
                  _hint,
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
