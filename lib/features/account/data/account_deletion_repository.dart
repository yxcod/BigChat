import '../../../utils/http.dart';

class AccountDeletionResult {
  const AccountDeletionResult({required this.code, required this.message});

  final int code;
  final String message;

  bool get isSuccess => code == 100;
}

class AccountDeletionRepository {
  const AccountDeletionRepository();

  Future<AccountDeletionResult> deleteAccount(String password) async {
    final response = await HttpUtil().post(
      '/api/user/deleteAccount',
      data: {'password': password},
    );
    final data = response.data;
    if (data is! Map) {
      return const AccountDeletionResult(code: 104, message: '服务器返回了无法识别的数据');
    }
    final rawCode = data['code'];
    final code = rawCode is int ? rawCode : int.tryParse('$rawCode') ?? 104;
    final message = '${data['message'] ?? ''}'.trim();
    return AccountDeletionResult(
      code: code,
      message: message.isEmpty ? _fallbackMessage(code) : message,
    );
  }

  String _fallbackMessage(int code) {
    return switch (code) {
      100 => '账户已注销',
      101 => '当前密码不正确',
      102 => '账号不存在或已注销',
      103 => '请先解散或转让由你创建的群聊',
      401 => '登录状态已失效，请重新登录',
      _ => '账户注销失败，请稍后重试',
    };
  }
}
