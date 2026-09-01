import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/cache/app_image_cache.dart';

class StorageUtil {
  static SharedPreferences? _prefs;
  static final GetStorage _box = GetStorage();
  static const String _imageDir = 'user_images';
  static bool _initialized = false;
  static bool _initializing = false;
  static Future<void>? _initFuture;

  static Future<void> init() async {
    if (_initialized) return;
    if (_initializing) return _initFuture;

    _initializing = true;
    _initFuture = _doInit();
    await _initFuture;
    _initialized = true;
    _initializing = false;
  }

  static Future<void> _doInit() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      //在Web平台下无法获取文件的存储目录
      if (!kIsWeb) {
        await _createImageDirectory();
      }
    } catch (e) {
      _initializing = false;
      rethrow;
    }
  }

  static Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  static Future<void> _createImageDirectory() async {
    if (kIsWeb) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${directory.path}/$_imageDir');
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
    } catch (e) {
      // Web 平台忽略目录创建错误
    }
  }

  static Future<bool> setString(String key, String value) async {
    await _ensureInitialized();
    return _prefs!.setString(key, value);
  }

  static String? getString(String key, {String? defaultValue}) {
    return _prefs?.getString(key) ?? defaultValue;
  }

  static Future<bool> setInt(String key, int value) async {
    await _ensureInitialized();
    return _prefs!.setInt(key, value);
  }

  static int? getInt(String key, {int? defaultValue}) {
    return _prefs?.getInt(key) ?? defaultValue;
  }

  static Future<bool> setDouble(String key, double value) async {
    await _ensureInitialized();
    return _prefs!.setDouble(key, value);
  }

  static double? getDouble(String key, {double? defaultValue}) {
    return _prefs?.getDouble(key) ?? defaultValue;
  }

  static Future<bool> setBool(String key, bool value) async {
    await _ensureInitialized();
    return _prefs!.setBool(key, value);
  }

  static bool? getBool(String key, {bool? defaultValue}) {
    return _prefs?.getBool(key) ?? defaultValue;
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    await _ensureInitialized();
    return _prefs!.setStringList(key, value);
  }

  static List<String>? getStringList(String key) {
    return _prefs?.getStringList(key);
  }

  static Future<bool> remove(String key) async {
    await _ensureInitialized();
    return _prefs!.remove(key);
  }

  static Future<bool> clear() async {
    await _ensureInitialized();
    return _prefs!.clear();
  }

  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  static Future<void> setUserInfo({
    required String userId,
    required String phone,
    required String nickname,
    String? avatar,
    required String token,
  }) async {
    await _ensureInitialized();
    await _prefs!.setString('user_id', userId);
    await _prefs!.setString('user_phone', phone);
    await _prefs!.setString('user_nickname', nickname);
    if (avatar != null) await _prefs!.setString('user_avatar', avatar);
    await _prefs!.setString('access_token', token);
    await _prefs!.setBool('is_login', true);
  }

  static Map<String, dynamic>? getUserInfo() {
    if (_prefs == null || !_prefs!.containsKey('is_login')) return null;
    return {
      'user_id': _prefs!.getString('user_id'),
      'user_phone': _prefs!.getString('user_phone'),
      'user_nickname': _prefs!.getString('user_nickname'),
      'user_avatar': _prefs!.getString('user_avatar'),
      'access_token': _prefs!.getString('access_token'),
      'is_login': _prefs!.getBool('is_login'),
    };
  }

  static bool isLoggedIn() {
    return _prefs?.getBool('is_login') ?? false;
  }

  /// Persists an authenticated session without storing the user's password.
  static Future<void> saveAuthenticatedSession({
    required String userName,
    required String token,
  }) async {
    await _ensureInitialized();
    final normalizedUserName = userName.trim();
    final normalizedToken = token.trim();
    if (normalizedUserName.isEmpty || normalizedToken.isEmpty) {
      throw ArgumentError('用户名和登录令牌不能为空');
    }
    await Future.wait([
      _prefs!.setString('global_userName', normalizedUserName),
      _prefs!.setString('global_token', normalizedToken),
      _prefs!.setString('user_id', normalizedUserName),
      _prefs!.setString('access_token', normalizedToken),
      _prefs!.setBool('is_login', true),
    ]);
  }

  /// Restores current and legacy session keys. Logout removes all these keys,
  /// so a session is restored only when the user did not explicitly sign out.
  static Future<bool> restoreAuthenticatedSession() async {
    await _ensureInitialized();
    final userName =
        (_prefs!.getString('global_userName') ??
                _prefs!.getString('user_id') ??
                _prefs!.getString('user_phone'))
            ?.trim();
    final token =
        (_prefs!.getString('global_token') ?? _prefs!.getString('access_token'))
            ?.trim();
    if (userName == null ||
        userName.isEmpty ||
        token == null ||
        token.isEmpty) {
      return false;
    }
    // Also migrates sessions created by older app versions that did not write
    // the is_login flag but did persist global_userName/global_token.
    await saveAuthenticatedSession(userName: userName, token: token);
    return true;
  }

  static Future<bool> logout() async {
    await _ensureInitialized();
    await AppImageCache.clear();
    await clearAllImages();
    return clearAuthenticatedSession();
  }

  /// Removes every locally persisted trace of an account after permanent
  /// deletion. Normal logout intentionally keeps app preferences; account
  /// deletion does not.
  static Future<void> purgeDeletedAccountData() async {
    await _ensureInitialized();
    await AppImageCache.clear();
    if (!kIsWeb) {
      final documents = await getApplicationDocumentsDirectory();
      for (final name in <String>[
        _imageDir,
        'chat_cache',
        'moments',
        'moment_notifications',
        'downloaded_videos',
      ]) {
        final directory = Directory('${documents.path}/$name');
        if (await directory.exists()) await directory.delete(recursive: true);
      }
      final support = await getApplicationSupportDirectory();
      for (final name in <String>[
        'chat_video_cache',
        'chat_voice_cache',
        'group_resource_image_cache',
        'video_thumbnails_v2',
      ]) {
        final directory = Directory('${support.path}/$name');
        if (await directory.exists()) await directory.delete(recursive: true);
      }
    }
    await _box.erase();
    await _prefs!.clear();
    if (!kIsWeb) await _createImageDirectory();
  }

  static Future<bool> clearAuthenticatedSession() async {
    await _ensureInitialized();
    await _prefs!.remove('user_id');
    await _prefs!.remove('user_phone');
    await _prefs!.remove('user_nickname');
    await _prefs!.remove('user_avatar');
    await _prefs!.remove('access_token');
    await _prefs!.remove('global_token');
    await _prefs!.remove('global_userName');
    await _prefs!.remove('global_isLoading');
    return _prefs!.setBool('is_login', false);
  }

  static Future<bool> setToken(String token) async {
    await _ensureInitialized();
    return _prefs!.setString('access_token', token);
  }

  static String? getToken() {
    return _prefs?.getString('access_token');
  }

  static Future<bool> setUserId(String userId) async {
    await _ensureInitialized();
    return _prefs!.setString('user_id', userId);
  }

  static String? getUserId() {
    return _prefs?.getString('user_id');
  }

  static Future<bool> setThemeMode(bool isDark) async {
    await _ensureInitialized();
    return _prefs!.setBool('theme_dark', isDark);
  }

  static bool isDarkMode() {
    return _prefs?.getBool('theme_dark') ?? false;
  }

  static Future<bool> setLanguageCode(String languageCode) async {
    await _ensureInitialized();
    return _prefs!.setString('language_code', languageCode);
  }

  static String? getLanguageCode() {
    return _prefs?.getString('language_code') ?? 'zh';
  }

  static Future<bool> setChatBackground(String? backgroundPath) async {
    await _ensureInitialized();
    if (backgroundPath != null) {
      return _prefs!.setString('chat_background', backgroundPath);
    } else {
      return _prefs!.remove('chat_background');
    }
  }

  static String? getChatBackground() {
    return _prefs?.getString('chat_background');
  }

  static Future<bool> setNotificationEnabled(bool enabled) async {
    await _ensureInitialized();
    return _prefs!.setBool('notification_enabled', enabled);
  }

  static bool isNotificationEnabled() {
    return _prefs?.getBool('notification_enabled') ?? true;
  }

  // 保存图片（Uint8List）到文件系统
  static Future<String> saveImage({
    required String key,
    required Uint8List imageBytes,
    String? subDir,
  }) async {
    await _ensureInitialized();
    final directory = await getApplicationDocumentsDirectory();
    final imageDir = Directory(
      '${directory.path}/$_imageDir${subDir != null ? '/$subDir' : ''}',
    );
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    final previousPath = _prefs!.getString('image_path_$key');
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$key';
    final file = File('${imageDir.path}/$fileName');
    await file.writeAsBytes(imageBytes);
    final imagePath = file.path;
    await _prefs!.setString('image_path_$key', imagePath);
    if (previousPath != null && previousPath != imagePath) {
      final previousFile = File(previousPath);
      if (await previousFile.exists()) await previousFile.delete();
    }
    return imagePath;
  }

  static Future<String?> saveImageBase64({
    required String key,
    required String base64String,
  }) async {
    try {
      await _ensureInitialized();
      await _box.write('image_$key', base64String);
      return base64String;
    } catch (e) {
      return null;
    }
  }

  static String? getImageBase64(String key) {
    return _box.read('image_$key');
  }

  //读取图片
  static Future<Uint8List?> getImageBytes(String key) async {
    await _ensureInitialized();
    final imagePath = _prefs?.getString('image_path_$key');
    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    }
    final base64String = _box.read('image_$key');
    if (base64String != null) {
      return base64Decode(base64String);
    }
    return null;
  }

  static Future<String?> getImagePath(String key) async {
    await _ensureInitialized();
    return _prefs?.getString('image_path_$key');
  }

  static Future<bool> deleteImage(String key) async {
    await _ensureInitialized();
    final imagePath = _prefs?.getString('image_path_$key');
    if (imagePath != null) {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    _box.remove('image_$key');
    return _prefs!.remove('image_path_$key');
  }

  static Future<void> saveUserAvatar(Uint8List imageBytes) async {
    await saveImage(key: 'avatar', imageBytes: imageBytes, subDir: 'avatars');
    await _prefs!.setString('user_avatar_type', 'local');
  }

  static Future<Uint8List?> getUserAvatar() async {
    await _ensureInitialized();
    final avatarType = _prefs?.getString('user_avatar_type');
    if (avatarType == 'local') {
      return await getImageBytes('avatar');
    }
    return null;
  }

  static Future<String> saveChatImage({
    required String chatId,
    required Uint8List imageBytes,
  }) async {
    return await saveImage(
      key: 'chat_$chatId',
      imageBytes: imageBytes,
      subDir: 'chats/$chatId',
    );
  }

  static Future<List<Uint8List>> getChatImages(String chatId) async {
    await _ensureInitialized();
    final List<Uint8List> images = [];
    final directory = await getApplicationDocumentsDirectory();
    final chatDir = Directory('${directory.path}/$_imageDir/chats/$chatId');
    if (await chatDir.exists()) {
      final files = chatDir.listSync();
      for (var file in files) {
        if (file is File) {
          images.add(await file.readAsBytes());
        }
      }
    }
    return images;
  }

  static Future<void> clearAllImages() async {
    await _ensureInitialized();
    final directory = await getApplicationDocumentsDirectory();
    final imageDir = Directory('${directory.path}/$_imageDir');
    if (await imageDir.exists()) {
      await imageDir.delete(recursive: true);
      await _createImageDirectory();
    }
    final imageKeys = (_box.getKeys() as Iterable)
        .whereType<String>()
        .where((key) => key.startsWith('image_'))
        .toList();
    for (final key in imageKeys) {
      await _box.remove(key);
    }
  }
}
