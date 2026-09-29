import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../widgets/logout_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = AuthService().currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.homeTitle),
        actions: const [LogoutButton()],
      ),
      body: Center(
        child: Text(
          'مرحباً بك في لوحة الإدارة\n$email',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
