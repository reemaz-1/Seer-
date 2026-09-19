import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../screens/login_screen.dart';

/// اللوق اوت — زر تسجيل الخروج مع رسالة تأكيد.
/// ضعه في الـ AppBar أو صفحة الحساب في أي من التطبيقين.
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key, required this.role});

  final AppRole role;

  Future<void> _confirmAndLogOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج من حسابك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await AuthService().logOut();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(role: role)),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'تسجيل الخروج',
      icon: const Icon(Icons.logout),
      onPressed: () => _confirmAndLogOut(context),
    );
  }
}
