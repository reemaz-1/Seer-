// Firebase types mocked only for isolated failure tests.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/services/auth_service.dart';

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _MockCredential extends Mock implements UserCredential {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

class _MockCollection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class _MockDocument extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class _MockSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late _MockAuth auth;
  late _MockUser user;
  late _MockCredential credential;
  late _MockFirestore firestore;
  late _MockCollection providers;
  late _MockDocument document;
  late _MockSnapshot snapshot;
  late AuthService service;
  User? currentUser;
  Map<String, dynamic>? profile;
  late List<String> operations;

  const uid = 'provider-account-a';
  const email = 'provider@example.com';
  const password = 'Test-password-123';
  const registrationProfile = <String, dynamic>{
    'firstName': 'Test',
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

  setUpAll(() {
    registerFallbackValue(const GetOptions());
  });

  setUp(() {
    auth = _MockAuth();
    user = _MockUser();
    credential = _MockCredential();
    firestore = _MockFirestore();
    providers = _MockCollection();
    document = _MockDocument();
    snapshot = _MockSnapshot();
    currentUser = null;
    profile = <String, dynamic>{'status': 'approved', 'firstName': 'Test'};
    operations = [];

    when(() => user.uid).thenReturn(uid);
    when(() => credential.user).thenReturn(user);
    when(() => auth.currentUser).thenAnswer((_) => currentUser);
    when(() => auth.authStateChanges()).thenAnswer((_) => const Stream.empty());
    when(
      () => auth.signInWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      currentUser = user;
      return credential;
    });
    when(
      () => auth.createUserWithEmailAndPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async {
      operations.add('create');
      currentUser = user;
      return credential;
    });
    when(() => auth.signOut()).thenAnswer((_) async {
      operations.add('signOut');
      currentUser = null;
    });
    when(() => user.sendEmailVerification()).thenAnswer((_) async {
      operations.add('verify');
    });
    when(() => user.delete()).thenAnswer((_) async {
      operations.add('delete');
      currentUser = null;
    });
    when(() => firestore.collection('providers')).thenReturn(providers);
    when(() => providers.doc(uid)).thenReturn(document);
    when(() => document.get()).thenAnswer((_) async => snapshot);
    when(() => document.get(any())).thenAnswer((_) async => snapshot);
    when(() => snapshot.exists).thenAnswer((_) => profile != null);
    when(() => snapshot.data()).thenAnswer((_) => profile);
    when(() => document.set(any())).thenAnswer((_) async {
      operations.add('save');
    });
    when(() => document.update(any())).thenAnswer((_) async {});

    service = AuthService(auth: auth, firestore: firestore);
  });

  tearDown(() => service.dispose());

  group('provider login', () {
    test('approved provider can log in with a trimmed email', () async {
      final result = await service.logIn(email: ' $email ', password: password);

      expect(result, same(user));
      expect(service.currentUser, same(user));
      expect(service.isAuthenticating, isFalse);
      verify(
        () => auth.signInWithEmailAndPassword(email: email, password: password),
      ).called(1);
      verify(() => firestore.collection('providers')).called(1);
      verify(() => providers.doc(uid)).called(1);
      verify(() => document.get(const GetOptions(source: Source.server)))
          .called(1);
      verifyNever(() => auth.signOut());
    });

    for (final status in ['pending', 'rejected', 'suspended', 'unknown', '']) {
      test('$status provider cannot retain an authenticated session', () async {
        profile = {'status': status};

        await expectLater(
          service.logIn(email: email, password: password),
          throwsA(isA<AuthException>()),
        );

        expect(service.currentUser, isNull);
        expect(service.isAuthenticating, isFalse);
        verify(() => auth.signOut()).called(1);
      });
    }

    test('an account without a provider profile is signed out', () async {
      profile = null;

      await expectLater(
        service.logIn(email: email, password: password),
        throwsA(isA<AuthException>()),
      );

      expect(service.currentUser, isNull);
      verify(() => auth.signOut()).called(1);
    });

    test('a profile without a status does not grant access', () async {
      profile = {'firstName': 'Test'};

      await expectLater(
        service.logIn(email: email, password: password),
        throwsA(isA<AuthException>()),
      );

      expect(service.currentUser, isNull);
      verify(() => auth.signOut()).called(1);
    });

    test('Firestore validation failure clears the signed-in session', () async {
      when(() => document.get(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );

      await expectLater(
        service.logIn(email: email, password: password),
        throwsA(isA<AuthException>()),
      );

      expect(service.currentUser, isNull);
      expect(service.isAuthenticating, isFalse);
      verify(() => auth.signOut()).called(1);
    });

    test('access stays busy until the provider profile is validated', () async {
      final profileRead = Completer<DocumentSnapshot<Map<String, dynamic>>>();
      when(() => document.get(any())).thenAnswer((_) => profileRead.future);
      final login = service.logIn(email: email, password: password);
      await Future<void>.delayed(Duration.zero);

      expect(service.isAuthenticating, isTrue);
      profileRead.complete(snapshot);
      await login;
      expect(service.isAuthenticating, isFalse);
    });
  });

  group('provider registration', () {
    test(
      'saves a pending application before verification and signs out',
      () async {
        final verificationSent = await service.registerProvider(
          email: ' $email ',
          password: password,
          profile: {
            ...registrationProfile,
            'email': 'untrusted@example.com',
            'status': 'approved',
            'createdAt': 'untrusted timestamp',
          },
        );

        final saved =
            verify(() => document.set(captureAny())).captured.single
                as Map<String, dynamic>;
        expect(saved['email'], email);
        expect(saved['status'], 'pending');
        expect(saved['createdAt'], isA<FieldValue>());
        for (final entry in registrationProfile.entries) {
          expect(saved[entry.key], entry.value);
        }
        expect(operations, ['create', 'save', 'verify', 'signOut']);
        expect(verificationSent, isTrue);
        expect(service.currentUser, isNull);
        expect(service.isAuthenticating, isFalse);
        verify(
          () => auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          ),
        ).called(1);
        verifyNever(() => user.delete());
      },
    );

    test(
      'verification failure preserves the saved pending application',
      () async {
        when(() => user.sendEmailVerification()).thenAnswer((_) async {
          operations.add('verify');
          throw FirebaseAuthException(code: 'too-many-requests');
        });

        final verificationSent = await service.registerProvider(
          email: email,
          password: password,
          profile: registrationProfile,
        );

        expect(verificationSent, isFalse);
        expect(operations, ['create', 'save', 'verify', 'signOut']);
        expect(service.currentUser, isNull);
        verify(() => document.set(any())).called(1);
        verifyNever(() => user.delete());
      },
    );

    test(
      'profile write failure deletes the new Auth user and signs out',
      () async {
        when(() => document.set(any())).thenAnswer((_) async {
          operations.add('save');
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        });

        await expectLater(
          service.registerProvider(
            email: email,
            password: password,
            profile: registrationProfile,
          ),
          throwsA(isA<AuthException>()),
        );

        expect(operations, ['create', 'save', 'delete', 'signOut']);
        expect(service.currentUser, isNull);
        expect(service.isAuthenticating, isFalse);
        verifyNever(() => user.sendEmailVerification());
      },
    );

    test(
      'an existing email does not delete or write a provider account',
      () async {
        when(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(FirebaseAuthException(code: 'email-already-in-use'));

        await expectLater(
          service.registerProvider(
            email: email,
            password: password,
            profile: registrationProfile,
          ),
          throwsA(isA<AuthException>()),
        );

        expect(service.currentUser, isNull);
        expect(service.isAuthenticating, isFalse);
        verifyNever(() => user.delete());
        verifyNever(() => document.set(any()));
        verifyNever(() => user.sendEmailVerification());
      },
    );
  });

  test(
    'failed account rollback still signs out the incomplete account',
    () async {
      when(() => document.set(any())).thenThrow(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      );
      when(() => user.delete())
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      await expectLater(
        service.registerProvider(
          email: email,
          password: password,
          profile: registrationProfile,
        ),
        throwsA(isA<AuthException>()),
      );

      expect(service.currentUser, isNull);
      expect(service.isAuthenticating, isFalse);
      verify(() => auth.signOut()).called(1);
      verifyNever(() => user.sendEmailVerification());
    },
  );

  group('provider profile isolation', () {
    test('reads and updates only the currently signed-in UID', () async {
      currentUser = user;
      final loaded = await service.getProviderProfile();
      const updates = <String, dynamic>{'firstName': 'Updated'};
      await service.updateProviderProfile(updates);

      expect(loaded, profile);
      verify(() => providers.doc(uid)).called(2);
      verify(() => document.update(updates)).called(1);
      verifyNever(() => providers.doc('provider-account-b'));
    });

    test('changing accounts changes the profile document being read', () async {
      currentUser = user;
      await service.getProviderProfile();
      final secondUser = _MockUser();
      final secondDocument = _MockDocument();
      final secondSnapshot = _MockSnapshot();
      when(() => secondUser.uid).thenReturn('provider-account-b');
      when(() => providers.doc('provider-account-b'))
          .thenReturn(secondDocument);
      when(() => secondDocument.get()).thenAnswer((_) async => secondSnapshot);
      when(() => secondSnapshot.exists).thenReturn(true);
      when(() => secondSnapshot.data()).thenReturn({'firstName': 'Second'});
      currentUser = secondUser;

      expect(await service.getProviderProfile(), {'firstName': 'Second'});
      verify(() => providers.doc(uid)).called(1);
      verify(() => providers.doc('provider-account-b')).called(1);
    });

    test('profile edits cannot overwrite approval or role fields', () async {
      currentUser = user;

      await service.updateProviderProfile({
        'firstName': 'Updated',
        'status': 'approved',
        'role': 'admin',
        'createdAt': 'modified timestamp',
      });

      final saved = verify(() => document.update(captureAny())).captured.single;
      expect(saved, {'firstName': 'Updated'});
    });

    test(
      'failed profile saves report an AuthException to the screen',
      () async {
        currentUser = user;
        when(() => document.update(any())).thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );

        await expectLater(
          service.updateProviderProfile({'firstName': 'Updated'}),
          throwsA(isA<AuthException>()),
        );
      },
    );

    test('signed-out profile reads and writes are rejected', () async {
      await expectLater(
        service.getProviderProfile(),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        service.updateProviderProfile({'firstName': 'Unauthorized'}),
        throwsA(isA<AuthException>()),
      );

      verifyNever(() => firestore.collection(any()));
      verifyNever(() => document.update(any()));
    });
  });

  test('logout clears the current session', () async {
    currentUser = user;

    await service.logOut();

    expect(service.currentUser, isNull);
    verify(() => auth.signOut()).called(1);
  });
}
