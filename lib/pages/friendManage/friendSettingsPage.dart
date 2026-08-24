import 'package:flutter/material.dart';

import '../../api/delete_chat_history_api.dart';
import '../../api/getFriendRequestsAPI.dart';
import '../../app/theme/app_colors.dart';
import '../../core/parsing/json_value_parser.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../utils/gloabl.dart';
import 'editFriendRemarkPage.dart';

typedef FriendRemarkUpdater =
    Future<Map<String, dynamic>> Function(
      String currentUserName,
      String friendUserName,
      String remark,
    );

class FriendSettingsResult {
  const FriendSettingsResult({
    required this.remark,
    this.friendDeleted = false,
  });

  final String remark;
  final bool friendDeleted;
}

class FriendSettingsPage extends StatefulWidget {
  const FriendSettingsPage({
    super.key,
    required this.friendData,
    this.remarkUpdater = updateFriendRemarkApi,
  });

  final Map<String, dynamic> friendData;
  final FriendRemarkUpdater remarkUpdater;

  @override
  State<FriendSettingsPage> createState() => _FriendSettingsPageState();
}

class _FriendSettingsPageState extends State<FriendSettingsPage> {
  final GlobalUtil _globalUtil = GlobalUtil();
  late String _remark;
  bool _isBusy = false;

  String get _friendUserName =>
      widget.friendData['userName']?.toString().trim() ?? '';

  @override
  void initState() {
    super.initState();
    _remark = widget.friendData['remark']?.toString().trim() ?? '';
  }

  void _close() {
    Navigator.pop(context, FriendSettingsResult(remark: _remark));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _editRemark() async {
    final newRemark = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => EditFriendRemarkPage(initialRemark: _remark),
      ),
    );
    if (!mounted || newRemark == null) return;

    final currentUserName = _globalUtil.userName ?? '';
    if (currentUserName.isEmpty || _friendUserName.isEmpty) {
      _showMessage('获取用户信息失败');
      return;
    }
    setState(() => _isBusy = true);
    try {
      final normalizedRemark = newRemark.trim();
      final response = await widget.remarkUpdater(
        currentUserName,
        _friendUserName,
        normalizedRemark,
      );
      if (!mounted) return;
      if (JsonValueParser.intValue(response['code'], fallback: -1) != 100) {
        throw Exception(response['msg'] ?? response['message'] ?? '备注修改失败');
      }
      _globalUtil.updateCachedFriendRemark(_friendUserName, normalizedRemark);
      setState(() => _remark = normalizedRemark);
      _showMessage('备注修改成功');
    } catch (error) {
      debugPrint('修改备注失败: $error');
      _showMessage('备注修改失败，请重试');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除聊天记录'),
        content: const Text(
          '删除后你将无法再查看当前历史记录，但不会影响对方保存的聊天记录。双方都删除后，服务器才会永久清理对应记录。确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final currentUserName = _globalUtil.userName ?? '';
    if (currentUserName.isEmpty || _friendUserName.isEmpty) {
      _showMessage('获取用户信息失败');
      return;
    }
    setState(() => _isBusy = true);
    try {
      final sessionId = GlobalUtil.generateSessionId(
        currentUserName,
        _friendUserName,
      );
      final response = await deletePrivateChatHistoryApi(
        userName: currentUserName,
        peerUserName: _friendUserName,
        conversationId: sessionId,
      );
      if (response['code'] != 100) {
        throw Exception(response['msg'] ?? '服务器删除失败');
      }
      await _globalUtil.deleteChatRecords(_friendUserName);
      _showMessage('聊天记录已删除');
    } catch (error) {
      debugPrint('删除聊天记录失败: $error');
      _showMessage('删除聊天记录失败，请重试');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteFriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除好友'),
        content: const Text('确定要删除该好友吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    final currentUserName = _globalUtil.userName ?? '';
    if (currentUserName.isEmpty || _friendUserName.isEmpty) {
      _showMessage('获取用户信息失败');
      return;
    }
    setState(() => _isBusy = true);
    try {
      final sessionId = GlobalUtil.generateSessionId(
        currentUserName,
        _friendUserName,
      );
      final response = await handledeleteFriendApi(
        currentUserName,
        _friendUserName,
        sessionId,
      );
      if (!mounted) return;
      if (response['code'] != 100) {
        throw Exception(response['msg'] ?? '好友删除失败');
      }
      _globalUtil.removeCachedFriend(_friendUserName);
      Navigator.pop(
        context,
        FriendSettingsResult(remark: _remark, friendDeleted: true),
      );
    } catch (error) {
      debugPrint('删除好友失败: $error');
      _showMessage('删除好友失败，请重试');
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: AppBackButton(onPressed: _close),
        title: const Text('设置'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE5E5E5)),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
            children: [
              _SettingsCard(
                children: [
                  _SettingsTile(
                    label: '备注',
                    value: _remark.isEmpty ? '未设置' : _remark,
                    onTap: _isBusy ? null : _editRemark,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DestructiveActionButton(
                key: const Key('delete_chat_history_button'),
                label: '删除聊天记录',
                color: const Color(0xFFE58A1F),
                onTap: _isBusy ? null : _deleteChatHistory,
              ),
              const SizedBox(height: 14),
              _DestructiveActionButton(
                key: const Key('delete_friend_button'),
                label: '删除好友',
                color: AppColors.danger,
                onTap: _isBusy ? null : _deleteFriend,
              ),
            ],
          ),
          if (_isBusy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.label, this.value, this.onTap});

  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const Key('friend_remark_tile'),
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 17)),
              ),
              if (value != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.5,
                  ),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 18,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.arrow_forward_ios,
                    key: Key('friend_remark_arrow'),
                    size: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestructiveActionButton extends StatelessWidget {
  const _DestructiveActionButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 58,
          child: Center(
            child: Text(label, style: TextStyle(color: color, fontSize: 17)),
          ),
        ),
      ),
    );
  }
}
