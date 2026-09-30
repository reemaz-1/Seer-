import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'service_provider_main.dart';
import '../widgets/logout_button.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService});
  final AuthService? authService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _auth = widget.authService ?? AuthService();
  StreamSubscription<User?>? _subscription;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  User? _user;
  bool _waiting = true;
  bool _authError = false;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_syncSession);
    _listen();
  }

  void _listen() {
    _subscription = _auth.authStateChanges.listen(
      (_) => _syncSession(),
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _authError = true;
            _waiting = false;
          });
        }
      },
    );
  }

  void _syncSession() {
    // Firebase emits a user before registration/profile validation completes.
    // Keep the current navigation tree until the whole operation has finished.
    if (!mounted || _auth.isAuthenticating) return;
    final user = _auth.currentUser;
    setState(() {
      if (user?.uid != _user?.uid) {
        _profile = user == null ? null : _auth.watchProvider(user.uid);
      }
      _user = user;
      _waiting = false;
      _authError = false;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _auth.removeListener(_syncSession);
    if (widget.authService == null) _auth.dispose();
    super.dispose();
  }

  Widget _session(String key, Widget screen) =>
      _SessionNavigator(key: ValueKey(key), screen: screen);

  @override
  Widget build(BuildContext context) {
    if (_waiting) return const _LoadingScreen();
    if (_authError) {
      return _status(
        icon: Icons.wifi_off_rounded,
        title: 'تعذر الاتصال',
        message: 'تعذر التحقق من تسجيل الدخول.',
        retry: () async {
          await _subscription?.cancel();
          if (!mounted) return;
          setState(() {
            _waiting = true;
            _authError = false;
          });
          _listen();
        },
      );
    }
    final user = _user;
    if (user == null) {
      return _session('signed-out', LoginScreen(authService: _auth));
    }
    // Email must be verified before the provider can see their account
    // status. After verifying, the screen calls _syncSession so we re-read
    // the (reloaded) user and continue to the status switch below.
    if (!user.emailVerified) {
      return _session(
        'verify-${user.uid}',
        EmailVerificationScreen(authService: _auth, onVerified: _syncSession),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      key: ValueKey(user.uid),
      stream: _profile,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _status(
            icon: Icons.wifi_off_rounded,
            title: 'تعذر تحميل الحساب',
            message: 'تعذر تحميل حالة الحساب. تحقق من الاتصال وحاول مرة أخرى.',
            retry: () => setState(() {
              _profile = _auth.watchProvider(user.uid);
            }),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting ||
            !snapshot.hasData) {
          return const _LoadingScreen();
        }
        final data = snapshot.data!.data();
        switch (data?['status']) {
          case 'approved':
            return _session(
              'approved-${user.uid}',
              ServiceProviderMain(
                authService: _auth,
                firstName: data?['firstName']?.toString() ?? '',
              ),
            );
          case 'pending':
            return _status(
              icon: Icons.hourglass_top_rounded,
              title: 'طلبك قيد المراجعة',
              message:
                  'تم استلام طلبك بنجاح، وهو بانتظار موافقة الإدارة. يمكنك تسجيل الدخول بعد اعتماد الطلب.',
            );
          case 'rejected':
            return _status(
              icon: Icons.close_rounded,
              title: 'تم رفض الطلب',
              message: 'تم رفض طلب تسجيلك. تواصل مع الإدارة.',
            );
          default:
            return _status(
              icon: Icons.lock_outline_rounded,
              title: 'غير مصرح',
              message: 'هذا الحساب غير مصرح له بالدخول إلى تطبيق مزود الخدمة.',
            );
        }
      },
    );
  }

  // Same look as the registration success screen: navy circle icon,
  // title, message, and full-width actions.
  Widget _status({
    required IconData icon,
    required String title,
    required String message,
    VoidCallback? retry,
  }) =>
      Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 48, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 36),
                  if (retry != null) ...[
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: retry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          LogoutButton.confirm(context, authService: _auth),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'تسجيل خروج',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

// Keep pushed routes inside the authenticated session and forward system back
// to its navigator. Replacing this widget drops the entire old route stack.
class _SessionNavigator extends StatefulWidget {
  const _SessionNavigator({super.key, required this.screen});
  final Widget screen;

  @override
  State<_SessionNavigator> createState() => _SessionNavigatorState();
}

class _SessionNavigatorState extends State<_SessionNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => NavigatorPopHandler<Object?>(
    onPopWithResult: (result) => _navigatorKey.currentState!.maybePop(result),
    child: Navigator(
      key: _navigatorKey,
      onGenerateRoute: (_) =>
          MaterialPageRoute<void>(builder: (_) => widget.screen),
    ),
  );
}
