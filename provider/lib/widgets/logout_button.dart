import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key, this.authService});

  final AuthService? authService;

  static Future<void> confirm(
    BuildContext context, {
    AuthService? authService,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await (authService ?? AuthService()).logOut();
    } on AuthException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'تسجيل الخروج',
    icon: const Icon(Icons.logout),
    onPressed: () => confirm(context, authService: authService),
  );
}
