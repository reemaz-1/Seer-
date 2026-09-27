import 'package:flutter_test/flutter_test.dart';
import 'package:customer/theme/app_colors.dart';

void main() {
  test('customer theme exposes its primary colors', () {
    expect(CustomerColors.background.toARGB32(), 0xFFFFFFFF);
    expect(CustomerColors.accent.toARGB32(), 0xFF1C63D6);
  });
}
