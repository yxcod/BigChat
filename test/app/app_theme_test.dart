import 'package:flutter_base/app/theme/app_colors.dart';
import 'package:flutter_base/app/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppTheme exposes a consistent brand color and component defaults', () {
    final theme = AppTheme.light;

    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.primaryColor, AppColors.primary);
    expect(theme.appBarTheme.backgroundColor, AppColors.surface);
    expect(theme.scaffoldBackgroundColor, AppColors.surface);
    expect(theme.useMaterial3, isFalse);
  });
}
