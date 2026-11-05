import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:customer/views/customer/email_verification_screen.dart';

class _Auth extends Fake implements FirebaseAuth {
  User? user;
  @override
  User? get currentUser => user;
}

class _User extends Fake implements User {
  bool verified = false;
  int tokenRefreshes = 0;
  Future<void> Function()? onReload;
  @override
  String get uid => 'customer';
  @override
  String get email => 'customer@example.com';
  @override
  bool get emailVerified => verified;
  @override
  Future<void> reload() async {
    await onReload?.call();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) tokenRefreshes++;
    return 'verified-token';
  }
}

void main() {
  testWidgets('verification uses the replacement User and refreshes claims', (
    tester,
  ) async {
    final auth = _Auth();
    final oldUser = _User();
    final freshUser = _User()..verified = true;
    auth.user = oldUser;
    oldUser.onReload = () async {
      auth.user = freshUser;
    };
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          auth: auth,
          onVerified: () => completions++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(completions, 1);
    expect(freshUser.tokenRefreshes, 1);
    expect(oldUser.tokenRefreshes, 0);
    await tester.pump(const Duration(seconds: 10));
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed refresh recovers and allows a manual retry', (
    tester,
  ) async {
    final auth = _Auth();
    final user = _User();
    auth.user = user;
    user.onReload = () async {
      throw FirebaseAuthException(code: 'network-request-failed');
    };
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          auth: auth,
          onVerified: () => completions++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final checkButton = find.widgetWithText(ElevatedButton, 'تحققت من بريدي');
    await tester.ensureVisible(checkButton);
    await tester.tap(checkButton);
    await tester.pumpAndSettle();
    expect(
      find.text('تعذر التحقق الآن. تحقق من اتصالك وحاول مرة أخرى.'),
      findsOneWidget,
    );
    expect(completions, 0);
    user.verified = true;
    user.onReload = null;
    await tester.ensureVisible(checkButton);
    await tester.tap(checkButton);
    await tester.pumpAndSettle();
    expect(completions, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
