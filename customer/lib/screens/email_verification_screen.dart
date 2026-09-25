import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.onVerified});

  final VoidCallback onVerified;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isSending = false;
  bool _isChecking = false;
  String? _message;

  Future<void> _resendEmail() async {
    setState(() {
      _isSending = true;
      _message = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() => _message = 'تم إرسال رابط التحقق من جديد إلى بريدك.');
    } catch (e) {
      setState(() => _message = 'تعذر إرسال الرابط، حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkVerified() async {
    setState(() {
      _isChecking = true;
      _message = null;
    });
    await FirebaseAuth.instance.currentUser?.reload();
    final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (verified) {
      widget.onVerified();
    } else if (mounted) {
      setState(() {
        _message = 'لم يتم التحقق من بريدك بعد.';
        _isChecking = false;
      });
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'تحقق من بريدك الإلكتروني',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'أرسلنا رابط تحقق إلى $email\nافتح الرابط ثم اضغط "تحققت من بريدي".',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                if (_message != null) ...[
                  Text(_message!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                ],
                ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerified,
                  child: _isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('تحققت من بريدي'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSending ? null : _resendEmail,
                  child: _isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إعادة إرسال رابط التحقق'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _logout,
                  child: const Text('تسجيل خروج'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}