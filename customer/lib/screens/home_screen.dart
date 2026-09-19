import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/logout_button.dart';

/// صفحة بسيطة بعد تسجيل الدخول — استبدلها بالصفحة الرئيسية الفعلية.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.role});

  final AppRole role;

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? '';
    return Theme(
      data: AppTheme.of(role),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الرئيسية'),
          actions: [LogoutButton(role: role)],
        ),
        body: Center(
          child: Text('مرحباً بك، $email'),
        ),
      ),
    );
  }
}
