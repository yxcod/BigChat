import 'package:flutter_base/utils/storageUtil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'authenticated session survives an app restart without a password',
    () async {
      SharedPreferences.setMockInitialValues({});
      await StorageUtil.init();

      await StorageUtil.saveAuthenticatedSession(
        userName: '13800138000',
        token: 'session-token',
      );

      expect(await StorageUtil.restoreAuthenticatedSession(), isTrue);
      expect(StorageUtil.getString('global_userName'), '13800138000');
      expect(StorageUtil.getString('global_token'), 'session-token');
      expect(StorageUtil.isLoggedIn(), isTrue);
      expect(StorageUtil.containsKey('password'), isFalse);

      await StorageUtil.clearAuthenticatedSession();
      expect(await StorageUtil.restoreAuthenticatedSession(), isFalse);
      expect(StorageUtil.isLoggedIn(), isFalse);
    },
  );
}
