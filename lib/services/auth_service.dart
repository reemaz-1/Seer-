import 'package:firebase_auth/firebase_auth.dart';

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
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  /// The currently signed-in user, or null if signed out.
  User? get currentUser => _auth.currentUser;

  /// Fires whenever the sign-in state changes (signed in / signed out).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// اللوق ان — تسجيل الدخول بالإيميل وكلمة المرور.
  Future<User> logIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw AuthException('تعذر تسجيل الدخول، حاول مرة أخرى.');
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  /// اللوق اوت — تسجيل الخروج.
  Future<void> logOut() async {
    await _auth.signOut();
  }

  /// ترسل رابط إعادة تعيين كلمة المرور إلى بريد المستخدم.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e.code));
    }
  }

  /// ترسل رابط تفعيل الحساب للمستخدم الحالي (يُستخدم بعد التسجيل مباشرة).
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('لا يوجد مستخدم مسجّل دخول حالياً.');
    }
    if (user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// حدّث بيانات المستخدم محلياً ثم ارجع true إذا صار الإيميل مفعّل.
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
        return 'حدث خطأ غير متوقع (${code}). حاول مرة أخرى.';
    }
  }
}
