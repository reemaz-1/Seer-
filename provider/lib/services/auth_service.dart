import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'device_alerts.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  bool _isAuthenticating = false;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isAuthenticating => _isAuthenticating;

  void _setAuthenticating(bool value) {
    _isAuthenticating = value;
    notifyListeners();
  }

  DocumentReference<Map<String, dynamic>> _provider(String uid) =>
      _firestore.collection('providers').doc(uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchProvider(String uid) =>
      _provider(uid).snapshots();

  Future<Map<String, dynamic>?> getProviderProfile() async {
    final user = currentUser;
    if (user == null) throw const AuthException('سجّل الدخول أولاً.');
    try {
      return (await _provider(user.uid).get()).data();
    } catch (error) {
      throw _asAuthException(error);
    }
  }

  Future<void> updateProviderProfile(Map<String, dynamic> updates) async {
    final user = currentUser;
    if (user == null) throw const AuthException('سجّل الدخول أولاً.');
    // Approval is managed by the admin app, never by profile edits.
    final allowed = Map<String, dynamic>.from(updates)
      ..remove('status')
      ..remove('createdAt')
      ..remove('role');
    try {
      await _provider(user.uid).update(allowed);
    } catch (error) {
      throw _asAuthException(error);
    }
  }

  Future<User> logIn({required String email, required String password}) async {
    if (_isAuthenticating) {
      throw const AuthException('انتظر اكتمال الطلب الحالي.');
    }
    _setAuthenticating(true);
    var signedIn = false;
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      signedIn = true;
      final user = credential.user;
      if (user == null) {
        throw const AuthException('تعذر تسجيل الدخول، حاول مرة أخرى.');
      }
      // NEW: an unverified provider stays signed in so AuthGate can show
      // the email verification screen. Account status is checked by
      // AuthGate after the email is verified.
      if (!user.emailVerified) {
        return user;
      }
      final data = (await _provider(
        user.uid,
      ).get(const GetOptions(source: Source.server))).data();
      switch (data?['status']) {
        case 'approved':
          return user;
        case 'unverified':
          // Verified the email but never opened the app afterwards, so the
          // request was not sent yet. Send it now, then treat it as pending.
          await submitForReviewIfVerified();
          throw const AuthException('طلب تسجيلك قيد المراجعة من الإدارة.');
        case 'pending':
          throw const AuthException('طلب تسجيلك قيد المراجعة من الإدارة.');
        case 'rejected':
          throw const AuthException('تم رفض طلب تسجيلك. تواصل مع الإدارة.');
        default:
          throw const AuthException(
            'هذا الحساب غير مصرح له بالدخول إلى تطبيق مزود الخدمة.',
          );
      }
    } catch (error) {
      if (signedIn) await logOut();
      throw _asAuthException(error);
    } finally {
      _setAuthenticating(false);
    }
  }

  /// Mail failure does not discard a successfully saved registration request.
  Future<bool> registerProvider({
    required String email,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    if (_isAuthenticating) {
      throw const AuthException('انتظر اكتمال الطلب الحالي.');
    }
    if (currentUser != null) {
      throw const AuthException('سجّل الخروج قبل إنشاء حساب جديد.');
    }
    _setAuthenticating(true);
    User? createdUser;
    var profileSaved = false;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) throw const AuthException('تعذر إنشاء الحساب.');
      await _provider(createdUser.uid).set({
        ...profile,
        'email': email.trim(),
        // Stays 'unverified' until the email is verified; only then does it
        // become 'pending' and appear in the admin app.
        'status': 'unverified',
        'createdAt': FieldValue.serverTimestamp(),
      });
      profileSaved = true;
      try {
        await createdUser.sendEmailVerification();
        return true;
      } on FirebaseAuthException {
        return false;
      }
    } catch (error) {
      if (createdUser != null && !profileSaved) {
        try {
          await createdUser.delete();
        } catch (_) {
          throw const AuthException(
            'تعذر حفظ طلبك وإلغاء الحساب غير المكتمل. تواصل مع الإدارة قبل إعادة التسجيل.',
          );
        }
      }
      throw _asAuthException(error);
    } finally {
      try {
        if (createdUser != null) await logOut();
      } finally {
        _setAuthenticating(false);
      }
    }
  }

  /// Sends the registration request to the admin by moving the provider
  /// from 'unverified' to 'pending', once their email is verified.
  /// Any other status is left as it is.
  Future<void> submitForReviewIfVerified() async {
    final user = currentUser;
    if (user == null) return;
    await user.reload();
    final fresh = _auth.currentUser;
    if (fresh == null || !fresh.emailVerified) return;
    // Refresh the sign-in token so it carries email_verified = true, which
    // the security rules check before allowing this change.
    await fresh.getIdToken(true);
    final ref = _provider(fresh.uid);
    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(ref);
        if (snapshot.data()?['status'] == 'unverified') {
          transaction.update(ref, {
            'status': 'pending',
            'submittedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (error) {
      throw _asAuthException(error);
    }
  }

  Future<void> logOut() async {
    // Ends availability mode (#47) so its fixed notification goes away.
    await DeviceAlerts.setAvailableMode(false);
    try {
      await _auth.signOut();
    } catch (error) {
      throw _asAuthException(error);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (error) {
      throw _asAuthException(error);
    }
  }

  AuthException _asAuthException(Object error) {
    if (error is AuthException) return error;
    if (error is FirebaseAuthException) {
      return AuthException(_mapAuthError(error.code));
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return const AuthException(
        'تعذر الوصول إلى بيانات الحساب. تواصل مع الإدارة.',
      );
    }
    return const AuthException('تعذر الاتصال ببيانات المستخدم. حاول مرة أخرى.');
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجل مسبقًا.';
      case 'weak-password':
      // Sent when the Firebase password policy is set to "Require".
      case 'password-does-not-meet-requirements':
        return 'كلمة المرور لا تستوفي الشروط المطلوبة.';
      case 'user-disabled':
        return 'هذا الحساب معطّل من قبل الإدارة.';
      case 'user-not-found':
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
