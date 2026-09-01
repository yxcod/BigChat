import 'dart:convert';

import '../../../model/userInfoModel.dart';
import '../../../utils/storageUtil.dart';

typedef UserInfoCacheReader = String? Function(String key);
typedef UserInfoCacheWriter = Future<void> Function(String key, String value);

class UserInfoCache {
  UserInfoCache({
    UserInfoCacheReader? readString,
    UserInfoCacheWriter? writeString,
  }) : _readString = readString ?? StorageUtil.getString,
       _writeString =
           writeString ??
           ((key, value) async {
             await StorageUtil.setString(key, value);
           });

  final UserInfoCacheReader _readString;
  final UserInfoCacheWriter _writeString;

  String storageKey(String ownerId) =>
      'user_info_snapshot_v1_${Uri.encodeComponent(ownerId)}';

  UserInfoModel? load(String ownerId) {
    final normalizedOwner = ownerId.trim();
    if (normalizedOwner.isEmpty) return null;
    try {
      final raw = _readString(storageKey(normalizedOwner));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final model = UserInfoModel.formJSON(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (model.userName?.trim() != normalizedOwner) return null;
      return model;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(String ownerId, UserInfoModel userInfo) async {
    final normalizedOwner = ownerId.trim();
    if (normalizedOwner.isEmpty ||
        userInfo.userName?.trim() != normalizedOwner) {
      return;
    }
    await _writeString(
      storageKey(normalizedOwner),
      jsonEncode(userInfo.toJson()),
    );
  }
}
