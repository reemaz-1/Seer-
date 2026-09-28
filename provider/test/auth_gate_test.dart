import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/main.dart';
import 'package:provider/screens/login_screen.dart';
import 'package:provider/screens/provider_profile_screen.dart';
import 'package:provider/screens/provider_registration_screen.dart';
import 'package:provider/services/auth_service.dart';
import 'package:provider/views/notifications.dart';
import 'package:provider/views/service_provider_main.dart';

class _MockAuthService extends Mock implements AuthService {
  final List<VoidCallback> _listeners = [];

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void emitServiceChange() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }
}

class _MockUser extends Mock implements User {}

// Firebase snapshots are mocked only at this test boundary.
// ignore: subtype_of_sealed_class
class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class _SessionHarness {
  final service = _MockAuthService();
  final user = _MockUser();
  final authEvents = StreamController<User?>.broadcast();
  final profileEvents =
      StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();

  User? currentUser;
  bool busy = false;
  Map<String, dynamic>? profile;

  _SessionHarness() {
    when(() => user.uid).thenReturn('current-provider');
    when(() => service.currentUser).thenAnswer((_) => currentUser);
    when(() => service.isAuthenticating).thenAnswer((_) => busy);
    when(() => service.authStateChanges).thenAnswer((_) => authEvents.stream);
    when(() => service.watchProvider('current-provider'))
        .thenAnswer((_) => profileEvents.stream);
    when(() => service.getProviderProfile()).thenAnswer((_) async => profile);
    when(() => service.logOut()).thenAnswer((_) async => signOut());
  }

  Future<void> mount(WidgetTester tester, {bool signedIn = false}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    currentUser = signedIn ? user : null;
    await tester.pumpWidget(MyApp(authService: service));
    authEvents.add(currentUser);
    await tester.pump();
    if (!signedIn) await tester.pumpAndSettle();
  }

  Future<void> approve(WidgetTester tester) async {
    await mount(tester, signedIn: true);
    emitProfile({'status': 'approved', 'firstName': 'ريم'});
    await tester.pumpAndSettle();
  }

  void emitProfile(Map<String, dynamic>? data) {
    profile = data;
    final snapshot = _MockSnapshot();
    when(() => snapshot.exists).thenReturn(data != null);
    when(() => snapshot.data()).thenReturn(data);
    profileEvents.add(snapshot);
  }

  void signOut() {
    currentUser = null;
    authEvents.add(null);
  }

  Future<void> dispose() async {
    await authEvents.close();
    await profileEvents.close();
  }
}

void main() {
  late _SessionHarness session;

  setUp(() => session = _SessionHarness());
  tearDown(() => session.dispose());

  testWidgets('signed-out provider can open registration and return to login', (
    tester,
  ) async {
    await session.mount(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ServiceProviderMain), findsNothing);
    await tester.tap(find.text('إنشاء حساب مزود خدمة'));
    await tester.pumpAndSettle();
    expect(find.byType(ProviderRegistrationScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(ProviderRegistrationScreen), findsNothing);
    verifyNever(() => session.service.logOut());
  });

  testWidgets(
    'restored approved session opens the actual provider application',
    (tester) async {
      await session.approve(tester);

      expect(find.byType(ServiceProviderMain), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('مرحباً، ريم'), findsNWidgets(2));
      verify(() => session.service.watchProvider('current-provider')).called(1);
    },
  );

  testWidgets(
    'empty registration form shows required errors without creating an account',
    (tester) async {
      await session.mount(tester);
      await tester.tap(find.text('إنشاء حساب مزود خدمة'));
      await tester.pumpAndSettle();
      final formScroll = find
          .descendant(
            of: find.byType(ProviderRegistrationScreen),
            matching: find.byType(Scrollable),
          )
          .first;
      final submit = find.widgetWithText(ElevatedButton, 'إرسال طلب التسجيل');
      await tester.scrollUntilVisible(submit, 350, scrollable: formScroll);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      verifyNever(
        () => session.service.registerProvider(
          email: any(named: 'email'),
          password: any(named: 'password'),
          profile: any(named: 'profile'),
        ),
      );
      expect(find.byType(ProviderRegistrationScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('الرجاء اختيار نوع المركبة'),
        -350,
        scrollable: formScroll,
      );
      expect(find.text('الرجاء اختيار نوع المركبة'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('الاسم الأول'),
        -350,
        scrollable: formScroll,
      );
      expect(find.text('الرجاء إدخال الاسم الأول'), findsOneWidget);
      expect(find.text('الرجاء إدخال البريد الإلكتروني'), findsOneWidget);
    },
  );

  testWidgets('system back respects a route that is busy and cannot pop', (
    tester,
  ) async {
    await session.mount(tester);
    Navigator.of(tester.element(find.byType(LoginScreen))).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const PopScope(
          canPop: false,
          child: Scaffold(body: Center(child: Text('Saving registration'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Saving registration'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  for (final entry in <String, String>{
    'pending': 'طلب تسجيلك قيد المراجعة من الإدارة.',
    'rejected': 'تم رفض طلب تسجيلك. تواصل مع الإدارة.',
    'missing': 'هذا الحساب غير مصرح له بالدخول إلى تطبيق مزود الخدمة.',
  }.entries) {
    testWidgets(
      '${entry.key} restored account cannot open provider application',
      (tester) async {
        await session.mount(tester, signedIn: true);
        session.emitProfile(
          entry.key == 'missing' ? null : {'status': entry.key},
        );
        await tester.pumpAndSettle();

        expect(find.text(entry.value), findsOneWidget);
        expect(find.byType(ServiceProviderMain), findsNothing);
        expect(find.byTooltip('تسجيل الخروج'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'signout discards a pushed notifications route and its back stack',
    (tester) async {
      await session.approve(tester);
      await tester.tap(find.byIcon(Icons.notifications_none));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderNotifications), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ServiceProviderMain), findsOneWidget);
      expect(find.byType(ProviderNotifications), findsNothing);
      await tester.tap(find.byIcon(Icons.notifications_none));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderNotifications), findsOneWidget);

      session.signOut();
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ProviderNotifications), findsNothing);
      expect(find.byType(ServiceProviderMain), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
    },
  );

  testWidgets(
    'revoking approval removes a pushed protected route immediately',
    (tester) async {
      await session.approve(tester);
      await tester.tap(find.byIcon(Icons.notifications_none));
      await tester.pumpAndSettle();

      session.emitProfile({'status': 'rejected', 'firstName': 'ريم'});
      await tester.pumpAndSettle();

      expect(find.text('تم رفض طلب تسجيلك. تواصل مع الإدارة.'), findsOneWidget);
      expect(find.byType(ProviderNotifications), findsNothing);
      expect(find.byType(ServiceProviderMain), findsNothing);
    },
  );

  testWidgets(
    'logout cancellation retains session and confirmation returns login',
    (tester) async {
      await session.approve(tester);
      await tester.tap(find.byTooltip('تسجيل الخروج'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
      await tester.pumpAndSettle();

      expect(find.byType(ServiceProviderMain), findsOneWidget);
      verifyNever(() => session.service.logOut());

      await tester.tap(find.byTooltip('تسجيل الخروج'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'تسجيل الخروج'));
      await tester.pumpAndSettle();

      verify(() => session.service.logOut()).called(1);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ServiceProviderMain), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('session loss dismisses an open logout confirmation dialog', (
    tester,
  ) async {
    await session.approve(tester);
    await tester.tap(find.byTooltip('تسجيل الخروج'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    session.signOut();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ServiceProviderMain), findsNothing);
  });

  testWidgets(
    'intermediate Firebase login event waits for profile validation',
    (tester) async {
      final validation = Completer<void>();
      when(
        () => session.service.logIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async {
        session.busy = true;
        session.currentUser = session.user;
        session.authEvents.add(session.user);
        await validation.future;
        session.busy = false;
        session.service.emitServiceChange();
        return session.user;
      });
      await session.mount(tester);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'rim@example.com',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Valid-password',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'تسجيل الدخول'));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ServiceProviderMain), findsNothing);
      verifyNever(() => session.service.watchProvider(any()));

      validation.complete();
      await tester.pump();
      session.emitProfile({'status': 'approved', 'firstName': 'ريم'});
      await tester.pumpAndSettle();

      expect(find.byType(ServiceProviderMain), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      verify(
        () => session.service.logIn(
          email: 'rim@example.com',
          password: 'Valid-password',
        ),
      ).called(1);
    },
  );

  testWidgets('account tab displays the injected current provider profile', (
    tester,
  ) async {
    await session.approve(tester);
    session.profile = {
      'status': 'approved',
      'firstName': 'ريم',
      'lastName': 'المزود',
      'email': 'current-provider@example.com',
      'phone': '0500000000',
    };
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is GButton && widget.icon == Icons.person_rounded,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProviderProfileScreen), findsOneWidget);
    expect(find.text('current-provider@example.com'), findsOneWidget);
    expect(find.text('ريم المزود'), findsOneWidget);
    verify(() => session.service.getProviderProfile()).called(1);
  });
}
