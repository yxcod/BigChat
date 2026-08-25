import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_context.dart';
import '../application/privacy_settings_service.dart';
import 'gesture_pattern_pad.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  final _service = PrivacySettingsService.instance;
  late double _readSeconds;
  late double _unreadSeconds;

  @override
  void initState() {
    super.initState();
    _readSeconds = _service.settings.readDestroySeconds.toDouble();
    _unreadSeconds = _service.settings.unreadDestroySeconds.toDouble();
  }

  Future<void> _saveDelays() async {
    await _service.setDestroyDelays(
      readSeconds: _readSeconds.round(),
      unreadSeconds: _unreadSeconds.round(),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('隐私参数已保存')));
    }
  }

  Future<void> _editGesture() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SetGesturePasswordPage()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appPageBackground,
      appBar: AppBar(title: const Text('隐私参数设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _DelayCard(
            title: '已读后销毁',
            description: '对方阅读后，双方消息将在设定时间后从内存销毁',
            value: _readSeconds,
            min: 5,
            max: 60,
            divisions: 11,
            onChanged: (value) => setState(() => _readSeconds = value),
          ),
          const SizedBox(height: 14),
          _DelayCard(
            title: '未读消息销毁',
            description: '即使消息一直未读，也会在设定时间后自动销毁',
            value: _unreadSeconds,
            min: 60,
            max: 300,
            divisions: 24,
            onChanged: (value) => setState(() => _unreadSeconds = value),
          ),
          const SizedBox(height: 14),
          Material(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              title: Text(
                _service.settings.hasGesturePassword ? '修改手势密码' : '设置手势密码',
              ),
              subtitle: const Text('隐私模式从后台恢复时用于解锁'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _editGesture,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: _saveDelays, child: const Text('保存设置')),
        ],
      ),
    );
  }
}

class _DelayCard extends StatelessWidget {
  const _DelayCard({
    required this.title,
    required this.description,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String title;
  final String description;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${value.round()} 秒',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: TextStyle(color: context.appTextSecondary, fontSize: 12.5),
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: '${value.round()} 秒',
              onChanged: onChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('${min.round()}秒'), Text('${max.round()}秒')],
            ),
          ],
        ),
      ),
    );
  }
}

class SetGesturePasswordPage extends StatefulWidget {
  const SetGesturePasswordPage({super.key});

  @override
  State<SetGesturePasswordPage> createState() => _SetGesturePasswordPageState();
}

class _SetGesturePasswordPageState extends State<SetGesturePasswordPage> {
  List<int>? _first;
  String _hint = '请连接至少4个点设置手势密码';

  Future<void> _complete(List<int> pattern) async {
    if (pattern.length < 4) {
      setState(() => _hint = '至少需要连接4个点，请重试');
      return;
    }
    if (_first == null) {
      setState(() {
        _first = pattern;
        _hint = '请再次绘制相同手势';
      });
      return;
    }
    if (_first!.join(',') != pattern.join(',')) {
      setState(() {
        _first = null;
        _hint = '两次手势不一致，请重新设置';
      });
      return;
    }
    await PrivacySettingsService.instance.setGesturePassword(pattern);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置手势密码')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(42, 54, 42, 20),
        child: Column(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 42),
            const SizedBox(height: 18),
            Text(_hint, textAlign: TextAlign.center),
            const SizedBox(height: 38),
            GesturePatternPad(onCompleted: _complete),
          ],
        ),
      ),
    );
  }
}
