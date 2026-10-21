import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme/app_colors.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.onVerified,
    this.auth,
  });

  final FirebaseAuth? auth;

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

  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;

  Future<bool> _refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null || fresh.uid != user.uid || !fresh.emailVerified) {
      return false;
    }
    await fresh.getIdToken(true);
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      final user = _auth.currentUser;
      if (user == null) throw StateError('Signed out');
      await user.sendEmailVerification();
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
      final verified = await _refreshEmailVerified();
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

  Future<void> _logout() async {
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? '';
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
                'افتح رابط التحقق ثم عد إلى التطبيق؛ سنتحقق تلقائيًا، أو اضغط تحققت من بريدي.',
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
                  onPressed: _isChecking ? null : () => _checkVerified(),
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
                  onPressed: _isSending || !_canResend ? null : _resendEmail,
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
                      : Text(
                          _canResend
                              ? 'إعادة إرسال رابط التحقق'
                              : 'انتظر دقيقة لإعادة الإرسال',
                          style: const TextStyle(fontSize: 16),
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
