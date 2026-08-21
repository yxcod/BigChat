import 'package:flutter_base/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('开发环境允许本地或临时 HTTP 服务', () {
      expect(
        () => AppConfig.validateValues(
          environment: 'development',
          apiBaseUrl: 'http://127.0.0.1:5555',
          webSocketBaseUrl: 'ws://127.0.0.1:5555',
        ),
        returnsNormally,
      );
    });

    test('生产环境拒绝明文 HTTP 和 WS', () {
      expect(
        () => AppConfig.validateValues(
          environment: 'production',
          apiBaseUrl: 'http://example.com',
          webSocketBaseUrl: 'ws://example.com',
        ),
        throwsStateError,
      );
    });

    test('生产环境接受 HTTPS 和 WSS', () {
      expect(
        () => AppConfig.validateValues(
          environment: 'production',
          apiBaseUrl: 'https://api.example.com',
          webSocketBaseUrl: 'wss://api.example.com',
        ),
        returnsNormally,
      );
    });
  });
}
