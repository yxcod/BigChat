import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../utils/storageUtil.dart';

typedef PermissionBatchRequester =
    Future<void> Function(List<Permission> permissions);
typedef InitialPermissionProvider = List<Permission> Function();

/// Requests the runtime permissions used by the app once, after the first UI
/// frame. Denied permissions remain requestable at the point a feature is used.
class InitialPermissionService {
  InitialPermissionService({
    PermissionBatchRequester? requester,
    InitialPermissionProvider? permissionProvider,
    bool Function()? hasRequested,
    Future<void> Function()? markRequested,
  }) : _requester = requester ?? _request,
       _permissionProvider = permissionProvider ?? _platformPermissions,
       _hasRequested =
           hasRequested ??
           (() => StorageUtil.getBool(_storageKey, defaultValue: false)!),
       _markRequested =
           markRequested ??
           (() async => StorageUtil.setBool(_storageKey, true));

  static final InitialPermissionService instance = InitialPermissionService();
  static const _storageKey = 'initial_runtime_permissions_requested_v1';

  final PermissionBatchRequester _requester;
  final InitialPermissionProvider _permissionProvider;
  final bool Function() _hasRequested;
  final Future<void> Function() _markRequested;

  Future<void> requestOnFirstLaunch() async {
    if (kIsWeb || _hasRequested()) return;
    try {
      final permissions = _permissionProvider();
      if (permissions.isNotEmpty) await _requester(permissions);
    } catch (error) {
      debugPrint('初始权限申请失败：$error');
    } finally {
      await _markRequested();
    }
  }

  static const List<Permission> iosInitialPermissions = <Permission>[
    Permission.notification,
    Permission.locationWhenInUse,
    Permission.microphone,
    Permission.camera,
    Permission.photos,
  ];

  static const List<Permission> androidInitialPermissions = <Permission>[
    Permission.notification,
    Permission.locationWhenInUse,
    Permission.microphone,
    Permission.camera,
    Permission.photos,
    Permission.videos,
    Permission.storage,
  ];

  static Future<void> _request(List<Permission> permissions) async {
    // Sequential requests keep the system prompts understandable and avoid
    // vendor Android ROMs dropping one of several simultaneous dialogs.
    for (final permission in permissions) {
      await permission.request();
    }
  }

  static List<Permission> _platformPermissions() {
    if (Platform.isIOS) return iosInitialPermissions;
    if (Platform.isAndroid) return androidInitialPermissions;
    return const <Permission>[];
  }
}
