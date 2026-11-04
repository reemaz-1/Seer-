import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thrown by [AuthService] with a ready-to-display Arabic message.
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

/// Wraps Firebase's Email/Password auth method — used by both the
/// Customer and the Service Provider apps (per the Seer project plan,
/// item #69: "Firebase authentication using a verification link via
/// email" and item #70: "Firebase password reset using link via email").
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestoreOverride = firestore;

  final FirebaseAuth _auth;

  // NEW: read lazily so creating an AuthService never touches Firestore.
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// NEW: true while [logIn] is checking that the account is a customer.
  /// AuthGate stays on the login screen meanwhile, so a rejected account
  /// never flashes another screen.
  static final ValueNotifier<bool> checkingAccount = ValueNotifier(false);

  /// The currently signed-in user, or null if signed out.
  User? get currentUser => _auth.currentUser;

  /// Fires whenever the sign-in state changes (signed in / signed out).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Log in: signs in with email and password.
  Future<User> logIn({required String email, required String password}) async {
    checkingAccount.value = true; // NEW
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw AuthException('تعذر تسجيل الدخول، حاول مرة أخرى.');
      }

      // NEW: only accounts with a document in `customers` can log in here.
      // Server read so an offline cache miss isn't mistaken for "not a customer".
      final DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await _firestore
            .collection('customers')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server));
      } catch (_) {
        await _auth.signOut();
        throw AuthException('تحقق من اتصالك بالإنترنت وحاول مرة أخرى.');
      }
      if (!doc.exists) {
        await _auth.signOut();
        throw AuthException(
          'هذا الحساب ليس حساب عميل. إذا كنت مزود خدمة، استخدم تطبيق مزود الخدمة.',
        );
      }
      if (doc.data()?['isSuspended'] == true) {
        await _auth.signOut();
        throw AuthException('تم إيقاف حسابك من قبل الإدارة. للتواصل مع دعم سير: ss222a@icloud.com');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    } finally {
      checkingAccount.value = false; // NEW
    }
  }

  /// Log out: signs the user out.
  Future<void> logOut() async {
    await _auth.signOut();
  }

  /// Sends a password reset link to the user's email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      /** Confirm that the email belongs to this app before sending its reset link. */
      final profiles = await _firestore.collection('customers')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (profiles.docs.isEmpty) {
        throw AuthException('هذا البريد ليس لحساب العميل. يرجى استخدام التطبيق المخصص لهذا الحساب.');
      }
      await _auth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: ActionCodeSettings(
          url: 'https://seer-8fd7c.firebaseapp.com/reset-password',
          handleCodeInApp: true,
          androidPackageName: 'com.swe444.seer',
          androidInstallApp: false,
        ),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  /// Sends an account verification link to the current user (used right after registration).
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('لا يوجد مستخدم مسجّل دخول حالياً.');
    }
    if (user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Reloads the user locally, then returns true if the email is now verified.
  Future<bool> refreshEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  String _mapError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-disabled':
        return 'هذا الحساب معطّل من قبل الإدارة.';
      case 'user-not-found':
        return 'لا يوجد حساب مرتبط بهذا البريد الإلكتروني.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'too-many-requests':
        return 'محاولات كثيرة متتالية، حاول لاحقاً.';
      case 'network-request-failed':
        return 'تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
      default:
        return 'حدث خطأ غير متوقع ($code). حاول مرة أخرى.';
    }
  }
}
