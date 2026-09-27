import 'package:flutter_test/flutter_test.dart';
import 'package:admin/config/app_config.dart';

void main() {
  test('admin app uses the correct role key', () {
    expect(AppConfig.roleKey, 'admin');
    expect(AppConfig.roleLabel, 'الإدارة');
  });
}
