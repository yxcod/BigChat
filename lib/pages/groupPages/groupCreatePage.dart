import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/getGroupInfoAPI.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_context.dart';
import '../../shared/widgets/app_back_button.dart';
import '../../utils/gloabl.dart';
import '../../utils/http.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final GlobalUtil _globalUtil = GlobalUtil();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _groupIdController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  XFile? _groupAvatar;
  String? _groupIdError;
  bool _isCreating = false;

  bool get _canCreate {
    return !_isCreating &&
        _groupAvatar != null &&
        _groupIdController.text.trim().length == 6 &&
        RegExp(r'^\d{6}$').hasMatch(_groupIdController.text.trim()) &&
        _groupNameController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _groupIdController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  void _validateGroupId(String value) {
    final normalized = value.trim();
    setState(() {
      if (normalized.isEmpty) {
        _groupIdError = null;
      } else if (!RegExp(r'^\d+$').hasMatch(normalized)) {
        _groupIdError = '群号只能输入数字';
      } else if (normalized.length != 6) {
        _groupIdError = '请输入6位群号';
      } else {
        _groupIdError = null;
      }
    });
  }

  Future<void> _pickGroupAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null || !mounted) return;

      if (await image.length() > 5 * 1024 * 1024) {
        _showMessage('图片不能超过5MB');
        return;
      }

      setState(() => _groupAvatar = image);
    } catch (_) {
      if (mounted) _showMessage('无法读取图片，请检查相册权限');
    }
  }

  String _avatarFileName(String path) {
    final extensionMatch = RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(path);
    final rawExtension = extensionMatch?.group(1)?.toLowerCase();
    final extension = switch (rawExtension) {
      'png' || 'webp' || 'jpeg' || 'jpg' => rawExtension!,
      _ => 'jpg',
    };
    return 'head_${DateTime.now().millisecondsSinceEpoch}.$extension';
  }

  Future<bool> _uploadGroupAvatar({
    required String groupId,
    required String groupName,
    required XFile avatar,
  }) async {
    final avatarName = _avatarFileName(avatar.path);
    final uploaded = await HttpUtil().uploadImageFile(
      avatarName,
      avatar.path,
      userName: groupId,
    );
    if (!uploaded) return false;

    final updateCode = await updateGroupInfo(
      _globalUtil.userName!,
      int.parse(groupId),
      groupName,
      'This is a new group',
      200,
      1,
      avatarName,
    );
    return updateCode == 100;
  }

  Future<void> _createGroup() async {
    FocusScope.of(context).unfocus();
    final groupId = _groupIdController.text.trim();
    final groupName = _groupNameController.text.trim();

    if (_groupAvatar == null) {
      _showMessage('请上传群头像');
      return;
    }
    if (groupId.isEmpty || groupName.isEmpty) {
      _showMessage('请填写群号和群名称');
      return;
    }
    _validateGroupId(groupId);
    if (!RegExp(r'^\d{6}$').hasMatch(groupId)) return;
    if (_globalUtil.userName == null) {
      _showMessage('用户信息未初始化，请重新登录');
      return;
    }

    setState(() => _isCreating = true);
    try {
      final code = await createGroup(
        _globalUtil.userName!,
        groupName,
        int.parse(groupId),
      );
      if (!mounted) return;

      if (code == 102) {
        _showMessage('群号已存在，请更换其他群号');
        return;
      }
      if (code != 100) {
        _showMessage('创建群聊失败，请稍后重试');
        return;
      }

      var avatarUpdated = false;
      try {
        avatarUpdated = await _uploadGroupAvatar(
          groupId: groupId,
          groupName: groupName,
          avatar: _groupAvatar!,
        );
      } catch (_) {
        avatarUpdated = false;
      }
      if (!mounted) return;
      if (!avatarUpdated) {
        _showMessage('群聊已创建，但群头像上传失败，可稍后在群设置中修改');
        Navigator.of(context).pop(true);
        return;
      }

      _showMessage('群聊创建成功');
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) _showMessage('创建群聊失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appSurface,
      appBar: AppBar(
        title: Text(
          '创建群聊',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.appSurface,
        surfaceTintColor: context.appSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: context.appSurface,
          statusBarIconBrightness: context.isDarkMode
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: context.isDarkMode
              ? Brightness.dark
              : Brightness.light,
        ),
        leading: const AppBackButton(),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: context.appDivider,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 52,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      _GroupAvatarPicker(
                        avatar: _groupAvatar,
                        onTap: _isCreating ? null : _pickGroupAvatar,
                      ),
                      const SizedBox(height: 38),
                      _buildFormCard(),
                      const Spacer(),
                      const SizedBox(height: 48),
                      _buildCreateButton(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appDivider),
      ),
      child: Column(
        children: [
          _GroupFormField(
            key: const ValueKey('group_id_field'),
            label: '群号',
            hintText: '请输入群号',
            controller: _groupIdController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            errorText: _groupIdError,
            onChanged: _validateGroupId,
          ),
          const Padding(
            padding: EdgeInsets.only(left: 22, right: 18),
            child: Divider(height: 0.5, thickness: 0.5),
          ),
          _GroupFormField(
            key: const ValueKey('group_name_field'),
            label: '群名称',
            hintText: '请输入群名称',
            controller: _groupNameController,
            maxLength: 30,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        key: const ValueKey('create_group_button'),
        onPressed: _canCreate ? _createGroup : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.42),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          elevation: 0,
        ),
        child: _isCreating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                '创建群聊',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _GroupAvatarPicker extends StatelessWidget {
  const _GroupAvatarPicker({required this.avatar, required this.onTap});

  final XFile? avatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '上传群头像',
      child: InkWell(
        key: const ValueKey('group_avatar_picker'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: context.appSearchBackground,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: avatar == null
                        ? const Icon(
                            Icons.groups_rounded,
                            size: 56,
                            color: AppColors.primary,
                          )
                        : Image.file(File(avatar!.path), fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.appSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.appDivider),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                avatar == null ? '上传群头像' : '更换群头像',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupFormField extends StatelessWidget {
  const _GroupFormField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.errorText,
    required this.onChanged,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 6, 18, 6),
      child: Row(
        crossAxisAlignment: errorText == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: errorText == null ? 0 : 14),
            child: SizedBox(
              width: 82,
              child: Text(
                label,
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              maxLength: maxLength,
              onChanged: onChanged,
              style: TextStyle(color: context.appTextPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 16,
                ),
                errorText: errorText,
                errorStyle: const TextStyle(fontSize: 12, height: 1),
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
