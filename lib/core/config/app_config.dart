class AppConfig {
  const AppConfig._();

  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://45.197.144.95:5555',
  );
  static const webSocketBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://45.197.144.95:5555',
  );

  static void validate() {
    validateValues(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      webSocketBaseUrl: webSocketBaseUrl,
    );
  }

  static void validateValues({
    required String environment,
    required String apiBaseUrl,
    required String webSocketBaseUrl,
  }) {
    final apiUri = Uri.tryParse(apiBaseUrl);
    final socketUri = Uri.tryParse(webSocketBaseUrl);
    if (apiUri == null || !apiUri.hasScheme || !apiUri.hasAuthority) {
      throw StateError('API_BASE_URL 配置无效');
    }
    if (socketUri == null || !socketUri.hasScheme || !socketUri.hasAuthority) {
      throw StateError('WS_BASE_URL 配置无效');
    }
    if (environment.toLowerCase() == 'production' &&
        (apiUri.scheme != 'https' || socketUri.scheme != 'wss')) {
      throw StateError('生产环境必须使用 HTTPS 和 WSS');
    }
  }
}
