import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/logout_button.dart';

/// Shown by AuthGate when a provider is signed in but hasn't verified
/// their email yet. Once verified, [onVerified] lets AuthGate re-read
/// the user and continue to the account status (pending/approved/...).
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.authService,
    required this.onVerified,
  });

  final AuthService authService;
  final VoidCallback onVerified;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  bool _isSending = false;
  bool _isChecking = false;
  bool _completed = false;
  bool _canResend = true;
  String? _message;
  Timer? _pollTimer;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.authService.verificationEmailSent) {
      _message = 'تم إنشاء حسابك، لكن تعذر إرسال الرابط. اضغط إعادة إرسال رابط التحقق.';
    }
    _startPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkVerified(silent: true);
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkVerified(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _checkVerified(silent: true);
    } else {
      _pollTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  Future<void> _resendEmail() async {
    if (_isSending || !_canResend || _completed) return;
    setState(() {
      _isSending = true;
      _message = null;
    });
    try {
      await widget.authService.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        _message = 'تم إرسال رابط التحقق من جديد. تحقق أيضًا من البريد غير المرغوب فيه.';
        _canResend = false;
      });
      _resendTimer = Timer(const Duration(minutes: 1), () {
        if (mounted) setState(() => _canResend = true);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'تعذر إرسال الرابط، حاول مرة أخرى بعد قليل.');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _checkVerified({bool silent = false}) async {
    if (!mounted || _isChecking || _completed) return;
    setState(() {
      _isChecking = true;
      if (!silent) _message = null;
    });
    try {
      final verified = await widget.authService.refreshEmailVerified();
      if (!mounted) return;
      if (verified) {
        _completed = true;
        _pollTimer?.cancel();
        widget.onVerified();
      } else if (!silent) {
        setState(
          () => _message =
              'لم يكتمل التحقق بعد. افتح أحدث رابط أرسلناه ثم حاول مجددًا.',
        );
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(
          () => _message = 'تعذر التحقق الآن. تحقق من اتصالك وحاول مرة أخرى.',
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.authService.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Brand header — same as provider login
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/icon/icon.jpg',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'سير',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppColors.navy,
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
                    color: AppColors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 42,
                    color: AppColors.blue,
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
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'أرسلنا رابط تحقق إلى',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'الخطوة 1: افتح رابط التحقق ثم عد إلى التطبيق؛ سنتحقق تلقائيًا. الخطوة 2: يُرسل طلبك للإدارة، ويمكنك متابعة حالته هنا حتى اعتماده.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.secondaryText),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.blue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _message!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.navy,
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
                  onPressed: _isChecking ? null : () => _checkVerified(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
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
                  onPressed: _isSending || !_canResend ? null : _resendEmail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.cardBorder),
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
                            color: AppColors.blue,
                          ),
                        )
                      : Text(
                          _canResend
                              ? 'إعادة إرسال رابط التحقق'
                              : 'انتظر دقيقة لإعادة الإرسال',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Logout — reuses the app's existing confirm dialog
              Center(
                child: TextButton(
                  onPressed: () => LogoutButton.confirm(
                    context,
                    authService: widget.authService,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondaryText,
                  ),
                  child: const Text('تسجيل خروج'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
