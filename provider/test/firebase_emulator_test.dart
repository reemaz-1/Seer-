// Run with local Auth (9099) and Firestore (8080) emulators:
// flutter test --platform chrome --dart-define=RUN_FIREBASE_EMULATOR_TESTS=true \
//   test/firebase_emulator_test.dart
// This suite uses a demo project and never imports production Firebase options.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/services/auth_service.dart';

import 'support/firebase_web_plugins_stub.dart'
    if (dart.library.js_interop) 'support/firebase_web_plugins.dart';

const _runEmulators = bool.fromEnvironment('RUN_FIREBASE_EMULATOR_TESTS');
const _project = 'demo-seer-provider';
const _password = 'Emulator-only-password-123';
const _profile = <String, dynamic>{
  'firstName': 'First',
  'lastName': 'Provider',
  'phone': '0500000000',
  'nationalId': '1000000000',
  'vehicleBrand': 'Toyota',
  'vehicleModel': 'Hilux',
  'vehicleYear': '2020',
  'servicesOffered': {
    'battery': {
      'options': [
        {'id': 'activation', 'enabled': true},
      ],
    },
  },
};

Uri _providerUri(String uid, {String? updateField}) => Uri.http(
  '127.0.0.1:8080',
  '/v1/projects/$_project/databases/(default)/documents/providers/$uid',
  updateField == null ? null : {'updateMask.fieldPaths': updateField},
);

const _adminHeaders = {
  'Authorization': 'Bearer owner',
  'Content-Type': 'application/json',
};

Future<void> _setStatus(String uid, String status) async {
  final response = await http.patch(
    _providerUri(uid, updateField: 'status'),
    headers: _adminHeaders,
    body: jsonEncode({
      'fields': {
        'status': {'stringValue': status},
      },
    }),
  );
  expect(response.statusCode, 200, reason: response.body);
}

Matcher _authErrorContaining(String message) => throwsA(
  isA<AuthException>().having(
    (error) => error.message,
    'message',
    contains(message),
  ),
);

void main() {
  if (!_runEmulators) {
    test(
      'real Firebase SDK integration',
      () {},
      skip:
          'Requires local emulators, --platform chrome, and '
          '--dart-define=RUN_FIREBASE_EMULATOR_TESTS=true.',
    );
    return;
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  late FirebaseApp app;
  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late AuthService service;
  final createdUids = <String>[];
  final runId = DateTime.now().microsecondsSinceEpoch;
  var accountNumber = 0;

  String nextEmail() => 'provider-$runId-${accountNumber++}@example.test';

  Future<String> registerAccount(
    String email, {
    Map<String, dynamic> profile = _profile,
  }) async {
    final verificationSent = await service.registerProvider(
      email: ' $email ',
      password: _password,
      profile: profile,
    );
    expect(verificationSent, isTrue);
    expect(service.currentUser, isNull);
    expect(service.isAuthenticating, isFalse);

    // Inspect the just-created account through the real SDK; the application
    // service separately checks provider approval before granting access.
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: _password,
    );
    final uid = credential.user!.uid;
    createdUids.add(uid);
    await auth.signOut();
    return uid;
  }

  setUpAll(() async {
    if (!kIsWeb) {
      throw StateError(
        'Run emulator integration tests with --platform chrome.',
      );
    }
    registerFirebaseWebPlugins();
    app = await Firebase.initializeApp(
      name: 'provider-emulator-$runId',
      options: const FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:1234567890:web:provider-emulator',
        messagingSenderId: '1234567890',
        projectId: _project,
        authDomain: 'demo-seer-provider.firebaseapp.com',
      ),
    );
    auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator('127.0.0.1', 9099, automaticHostMapping: false);
    await auth.setPersistence(Persistence.NONE);
    firestore = FirebaseFirestore.instanceFor(app: app);
    firestore.settings = const Settings(persistenceEnabled: false);
    firestore.useFirestoreEmulator('127.0.0.1', 8080);
    service = AuthService(auth: auth, firestore: firestore);
  });

  setUp(() async {
    await service.logOut();
  });

  tearDown(() async {
    await service.logOut();
  });

  tearDownAll(() async {
    for (final uid in createdUids) {
      final documentDelete = await http.delete(
        _providerUri(uid),
        headers: _adminHeaders,
      );
      expect(documentDelete.statusCode, anyOf(200, 404));
      final accountDelete = await http.post(
        Uri.http(
          '127.0.0.1:9099',
          '/identitytoolkit.googleapis.com/v1/accounts:delete',
          {'key': 'demo-api-key'},
        ),
        headers: _adminHeaders,
        body: jsonEncode({'localId': uid}),
      );
      expect(accountDelete.statusCode, 200, reason: accountDelete.body);
    }
    service.dispose();
    await firestore.terminate();
    await app.delete();
  });

  group('real Firebase Auth and Firestore provider flow', () {
    test(
      'registration saves a pending profile, signs out, and rejects duplicates',
      () async {
        final email = nextEmail();
        final uid = await registerAccount(
          email,
          profile: {
            ..._profile,
            'status': 'approved',
            'createdAt': 'untrusted timestamp',
            'email': 'untrusted@example.test',
          },
        );

        await auth.signInWithEmailAndPassword(
          email: email,
          password: _password,
        );
        final snapshot = await firestore
            .collection('providers')
            .doc(uid)
            .get(const GetOptions(source: Source.server));
        final saved = snapshot.data()!;
        expect(saved['email'], email);
        expect(saved['status'], 'pending');
        expect(saved['createdAt'], isA<Timestamp>());
        for (final field in _profile.entries) {
          expect(saved[field.key], field.value);
        }
        await auth.signOut();

        await expectLater(
          service.registerProvider(
            email: email,
            password: _password,
            profile: _profile,
          ),
          _authErrorContaining('مسجل مسبقًا'),
        );
        expect(service.currentUser, isNull);
        expect(service.isAuthenticating, isFalse);
      },
    );

    test(
      'pending and rejected providers are signed out after login is denied',
      () async {
        final email = nextEmail();
        final uid = await registerAccount(email);
        await expectLater(
          service.logIn(email: email, password: _password),
          _authErrorContaining('قيد المراجعة'),
        );
        expect(service.currentUser, isNull);
        expect(service.isAuthenticating, isFalse);

        await _setStatus(uid, 'rejected');
        await expectLater(
          service.logIn(email: email, password: _password),
          _authErrorContaining('رفض طلب'),
        );
        expect(service.currentUser, isNull);
        expect(service.isAuthenticating, isFalse);
      },
    );

    test(
      'admin approval permits login and each account keeps its own profile',
      () async {
        final firstEmail = nextEmail();
        final secondEmail = nextEmail();
        final firstUid = await registerAccount(firstEmail);
        final secondUid = await registerAccount(
          secondEmail,
          profile: {..._profile, 'firstName': 'Second'},
        );
        await _setStatus(firstUid, 'approved');
        await _setStatus(secondUid, 'approved');

        final firstUser = await service.logIn(
          email: ' $firstEmail ',
          password: _password,
        );
        expect(firstUser.uid, firstUid);
        expect((await service.getProviderProfile())!['firstName'], 'First');
        await service.updateProviderProfile({
          'firstName': 'Updated first',
          'status': 'rejected',
          'role': 'admin',
          'createdAt': 'untrusted timestamp',
        });
        final updated = (await service.getProviderProfile())!;
        expect(updated['firstName'], 'Updated first');
        expect(updated['status'], 'approved');
        expect(updated['createdAt'], isA<Timestamp>());
        expect(updated.containsKey('role'), isFalse);
        await service.logOut();
        expect(service.currentUser, isNull);
        await expectLater(
          service.getProviderProfile(),
          throwsA(isA<AuthException>()),
        );

        final secondUser = await service.logIn(
          email: secondEmail,
          password: _password,
        );
        expect(secondUser.uid, secondUid);
        expect(secondUid, isNot(firstUid));
        final secondProfile = (await service.getProviderProfile())!;
        expect(secondProfile['email'], secondEmail);
        expect(secondProfile['firstName'], 'Second');
        // Rules must also deny direct cross-account reads, beyond service routing.
        await expectLater(
          firestore
              .collection('providers')
              .doc(firstUid)
              .get(const GetOptions(source: Source.server)),
          throwsA(
            isA<FirebaseException>().having(
              (e) => e.code,
              'code',
              'permission-denied',
            ),
          ),
        );
        await service.logOut();
        await service.logIn(email: firstEmail, password: _password);
        expect(
          (await service.getProviderProfile())!['firstName'],
          'Updated first',
        );
        await service.logOut();
        expect(service.currentUser, isNull);
      },
    );

    test('an incorrect password cannot create a session', () async {
      final email = nextEmail();
      final uid = await registerAccount(email);
      await _setStatus(uid, 'approved');
      await expectLater(
        service.logIn(email: email, password: 'Wrong-password-123'),
        _authErrorContaining('غير صحيحة'),
      );
      expect(service.currentUser, isNull);
      expect(service.isAuthenticating, isFalse);
    });

    for (final hasProfile in [false, true]) {
      test(
        'an Auth account ${hasProfile ? 'without approval status' : 'without a provider profile'} cannot enter',
        () async {
          final email = nextEmail();
          final credential = await auth.createUserWithEmailAndPassword(
            email: email,
            password: _password,
          );
          final uid = credential.user!.uid;
          createdUids.add(uid);
          if (hasProfile) {
            await firestore.collection('providers').doc(uid).set({
              'firstName': 'No approval',
            });
          }
          await auth.signOut();

          await expectLater(
            service.logIn(email: email, password: _password),
            _authErrorContaining('غير مصرح'),
          );
          expect(service.currentUser, isNull);
          expect(service.isAuthenticating, isFalse);
        },
      );
    }
  });
}
