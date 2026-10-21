import 'package:flutter/material.dart';

import 'services/password_reset_link_handler.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/auth_service.dart';

import 'firebase_options.dart';
import 'views/customer/customer_main.dart';
import 'views/customer/login_screen.dart';
import 'views/customer/customer_registration_screen.dart';
import 'views/customer/email_verification_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check is not enforced yet. The debug provider fails in release
  // builds, so never let it stop the app from starting.
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );
  } catch (e) {
    debugPrint('App Check not activated: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      builder: (context, child) => PasswordResetLinkHandler(
        navigatorKey: _navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
      debugShowCheckedModeBanner: false,
      title: 'سير',
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.of(AppRole.customer),
      home: const AuthGate(),
      routes: {'/register': (context) => const CustomerRegistrationScreen()},
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  void _refresh() => setState(() {});

  // Created once so rebuilds don't resubscribe (which would reset the
  // login screen mid-login).
  late final Stream<User?> _authChanges = FirebaseAuth.instance
      .authStateChanges();

  // Cached per user so rebuilds don't open a new Firestore listener.
  String? _uid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _customerDoc;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _customerDocFor(String uid) {
    if (_uid != uid) {
      _uid = uid;
      _customerDoc = FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .snapshots();
    }
    return _customerDoc!;
  }

  static const _loading = Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.checkingAccount,
      builder: (context, checking, _) => StreamBuilder<User?>(
        stream: _authChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loading;
          }
          // reload() replaces currentUser; the stream may retain the old User.
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) _uid = null;

          // Stay on the login screen while logIn is still checking the
          // account, so its error message shows there.
          if (user == null || checking) {
            return const LoginScreen(role: AppRole.customer);
          }

          // Restored sessions skip logIn, so check the account here too.
          // A stream (not a one-time read) because on sign-up the auth
          // account exists a moment before its customer document is written.
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _customerDocFor(user.uid),
            builder: (context, docSnapshot) {
              if (docSnapshot.hasError) {
                return const _NotCustomerScreen(
                  title: 'تعذر التحقق من الحساب',
                  message: 'تحقق من اتصالك بالإنترنت ثم سجّل الدخول مرة أخرى.',
                );
              }
              final doc = docSnapshot.data;
              // Wait for the server before deciding the account isn't a customer.
              if (doc == null || (!doc.exists && doc.metadata.isFromCache)) {
                return _loading;
              }
              if (!doc.exists) {
                return const _NotCustomerScreen(
                  title: 'هذا الحساب ليس حساب عميل',
                  message: 'سجّل الدخول بحساب عميل، أو استخدم تطبيق مزود الخدمة إذا كان حسابك حساب مزود.',
                );
              }
              if (!user.emailVerified) {
                return EmailVerificationScreen(onVerified: _refresh);
              }
              return const CustomerMain();
            },
          );
        },
      ),
    );
  }
}

/// Shown when a restored session belongs to an account that can't use
/// the customer app.
class _NotCustomerScreen extends StatelessWidget {
  const _NotCustomerScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
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
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 34,
                      color: colors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    child: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(fontSize: 16),
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
}
