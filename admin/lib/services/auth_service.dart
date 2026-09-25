import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<bool> hasRequiredRole(User user) async {
    final snapshot = await _firestore.collection('admins').doc(user.uid).get();
    return snapshot.data()?['role']?.toString() == AppConfig.roleKey;
  }

  Future<User> logIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthException('تعذر تسجيل الدخول، حاول مرة أخرى.');
      }
      if (!await hasRequiredRole(user)) {
        await _auth.signOut();
        throw const AuthException(
          'هذا الحساب غير مصرح له بالدخول إلى لوحة الإدارة.',
        );
      }
      return user;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error.code));
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const AuthException('تعذر التحقق من صلاحية حساب الإدارة.');
      }
      throw const AuthException('تعذر الاتصال ببيانات المستخدم.');
    }
  }

  Future<void> logOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapAuthError(error.code));
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'user-disabled':
        return 'هذا الحساب معطّل.';
      case 'user-not-found':
        return 'لا يوجد حساب إدارة مرتبط بهذا البريد الإلكتروني.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 'too-many-requests':
        return 'محاولات كثيرة متتالية، حاول لاحقاً.';
      case 'network-request-failed':
        return 'تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
      default:
        return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
    }
  }
}
