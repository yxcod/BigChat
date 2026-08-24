import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../api/getInfoAPI.dart';
import '../app/theme/app_colors.dart';
import '../core/cache/app_image_cache.dart';
import '../model/userInfoModel.dart';
import '../shared/widgets/app_back_button.dart';
import '../utils/gloabl.dart';
import 'change_password_page.dart';
import 'profile_field_editor_page.dart';
import 'region_editor_page.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key, required this.profileInfo});

  final Map<String, dynamic>? profileInfo;

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  bool _isLoading = false;
  late String _nickName;
  late String _signature;
  late int _gender;
  late String _region;

  @override
  void initState() {
    super.initState();
    final current = GlobalUtil().userInfoModel;
    final info = widget.profileInfo ?? const <String, dynamic>{};
    _nickName = info['nickName']?.toString() ?? current.nickName ?? '';
    _signature = info['signature']?.toString() ?? current.signature ?? '';
    _gender = _parseGender(info['gender'], fallback: current.gender);
    _region = info['region']?.toString() ?? current.region;
  }

  int _parseGender(dynamic value, {required int fallback}) {
    if (value is int && value >= 0 && value <= 2) return value;
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed != null && parsed >= 0 && parsed <= 2 ? parsed : fallback;
  }

  String _buildAvatarUrl() {
    final avatarName = GlobalUtil().userInfoModel.avatar ?? 'head.jpg';
    return GlobalUtil().getImageURL(GlobalUtil().userName ?? '', avatarName);
  }

  Future<void> _changeAvatar() async {
    setState(() => _isLoading = true);
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final avatarFileName = 'head_$timestamp.jpg';
      final Uint8List? imageData = await GlobalUtil().selectAndUploadAvatar(
        avatarFileName,
      );
      if (!mounted) return;
      if (imageData == null) {
        _showMessage('头像修改取消或失败');
        return;
      }

      final current = GlobalUtil().userInfoModel;
      final updated = UserInfoModel(
        userName: current.userName,
        nickName: current.nickName,
        avatar: avatarFileName,
        gender: current.gender,
        region: current.region,
        signature: current.signature,
        friendListData: current.friendListData,
      );
      final code = await updateUserInfoApi(updated);
      if (!mounted) return;
      if (code == 100) {
        GlobalUtil().userInfoModel = updated;
        setState(() {});
        _showMessage('头像修改成功');
      } else {
        _showMessage('头像修改失败，请稍后重试');
      }
    } catch (error) {
      debugPrint('修改头像失败：$error');
      if (mounted) _showMessage('头像修改失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editText({
    required String title,
    required String initialValue,
    required String hintText,
    required int maxLength,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
  }) async {
    final value = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileFieldEditorPage(
          title: title,
          initialValue: initialValue,
          hintText: hintText,
          maxLength: maxLength,
          maxLines: maxLines,
        ),
      ),
    );
    if (value != null && mounted) setState(() => onChanged(value));
  }

  Future<void> _editGender() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '选择性别',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              for (final option in const [(0, '保密'), (1, '男'), (2, '女')])
                ListTile(
                  key: Key('gender_option_${option.$1}'),
                  title: Text(option.$2),
                  trailing: _gender == option.$1
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, option.$1),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _gender = selected);
  }

  Future<void> _editRegion() async {
    final region = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => RegionEditorPage(initialRegion: _region),
      ),
    );
    if (region != null && mounted) setState(() => _region = region);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _avatarRow() {
    final avatarUrl = _buildAvatarUrl();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          ClipOval(
            child: CachedNetworkImage(
              cacheManager: AppImageCache.manager,
              imageUrl: avatarUrl,
              cacheKey: AppImageCache.cacheKey(avatarUrl),
              fit: BoxFit.cover,
              width: 64,
              height: 64,
              progressIndicatorBuilder: (_, _, progress) => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.progress,
                ),
              ),
              errorWidget: (_, _, _) => Container(
                width: 64,
                height: 64,
                color: Colors.grey[200],
                child: Icon(Icons.person, color: Colors.grey[400], size: 34),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              '头像',
              style: TextStyle(fontSize: 17, color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            key: const Key('change_avatar_button'),
            onPressed: _changeAvatar,
            child: const Text('更换头像'),
          ),
        ],
      ),
    );
  }

  Widget _profileRow({
    required Key key,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 16),
            SizedBox(
              width: 86,
              child: Text(label, style: const TextStyle(fontSize: 16)),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '未设置' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 22, color: Color(0xFFB8B8B8)),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const AppBackButton(),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('编辑资料'),
        actions: [
          IconButton(
            key: const Key('open_change_password_page'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ChangePasswordPage(),
              ),
            ),
            icon: const Icon(Icons.lock, color: AppColors.primary),
            tooltip: '修改密码',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, thickness: 0.5),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _avatarRow(),
                      const Divider(height: 0.5, indent: 16),
                      _profileRow(
                        key: const Key('edit_nickname_row'),
                        label: '昵称',
                        value: _nickName,
                        onTap: () => _editText(
                          title: '设置昵称',
                          initialValue: _nickName,
                          hintText: '请输入昵称',
                          maxLength: 50,
                          onChanged: (value) => _nickName = value,
                        ),
                      ),
                      const Divider(height: 0.5, indent: 16),
                      _profileRow(
                        key: const Key('edit_gender_row'),
                        label: '性别',
                        value: userGenderLabel(_gender),
                        onTap: _editGender,
                      ),
                      const Divider(height: 0.5, indent: 16),
                      _profileRow(
                        key: const Key('edit_region_row'),
                        label: '地区',
                        value: _region,
                        onTap: _editRegion,
                      ),
                      const Divider(height: 0.5, indent: 16),
                      _profileRow(
                        key: const Key('edit_signature_row'),
                        label: '个性签名',
                        value: _signature,
                        onTap: () => _editText(
                          title: '设置个性签名',
                          initialValue: _signature,
                          hintText: '请输入个性签名',
                          maxLength: 200,
                          maxLines: 4,
                          onChanged: (value) => _signature = value,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  key: const Key('save_profile_button'),
                  onPressed: _isLoading ? null : _saveProfile,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('保存', style: TextStyle(fontSize: 17)),
                ),
                const SizedBox(height: 10),
                const Text(
                  '完善资料，让好友更了解你',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const ColoredBox(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_nickName.trim().isEmpty) {
      _showMessage('请输入昵称');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final current = GlobalUtil().userInfoModel;
      final updated = UserInfoModel(
        userName: current.userName,
        nickName: _nickName.trim(),
        avatar: current.avatar,
        gender: _gender,
        region: _region.trim(),
        signature: _signature.trim(),
        friendListData: current.friendListData,
      );
      final code = await updateUserInfoApi(updated);
      if (!mounted) return;
      if (code == 100) {
        GlobalUtil().userInfoModel = updated;
        _showMessage('个人信息保存成功');
        Navigator.pop(context, true);
      } else {
        _showMessage('个人信息保存失败，请稍后重试');
      }
    } catch (error) {
      debugPrint('保存个人信息失败：$error');
      if (mounted) _showMessage('个人信息保存失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
