import 'package:flutter_test/flutter_test.dart';
import 'package:provider/config/app_config.dart';

void main() {
  test('service provider app uses the correct role key', () {
    expect(AppConfig.roleKey, 'service_provider');
    expect(AppConfig.roleLabel, 'مزود الخدمة');
  });
}
