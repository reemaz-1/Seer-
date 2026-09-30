import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';

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
      backgroundColor: CustomerColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand header — same as login
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/icon/icon.jpg',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'سير',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: CustomerColors.primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Mail icon
              Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: CustomerColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 42,
                    color: CustomerColors.accent,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'تحقق من بريدك الإلكتروني',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: CustomerColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'أرسلنا رابط تحقق إلى',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: CustomerColors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: CustomerColors.primaryText,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'افتح الرابط ثم اضغط "تحققت من بريدي".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: CustomerColors.secondaryText,
                ),
              ),
              const SizedBox(height: 32),

              // Status message
              if (_message != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: CustomerColors.fieldFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CustomerColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: CustomerColors.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _message!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: CustomerColors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Primary: I've verified
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerified,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomerColors.darkPanel,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'تحققت من بريدي',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary: resend
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: _isSending ? null : _resendEmail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CustomerColors.primaryText,
                    side: const BorderSide(color: CustomerColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CustomerColors.accent,
                          ),
                        )
                      : const Text(
                          'إعادة إرسال رابط التحقق',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Logout
              Center(
                child: TextButton(
                  onPressed: _logout,
                  style: TextButton.styleFrom(
                    foregroundColor: CustomerColors.secondaryText,
                  ),
                  child: const Text('الرجوع لتسجيل الدخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
