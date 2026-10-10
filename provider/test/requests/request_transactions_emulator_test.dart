// Local demo project only. See docs/provider-requests.md for the emulator command.
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/models/provider_request_model.dart';
import 'package:provider/models/provider_location_model.dart';
import 'package:provider/models/order.dart';
import 'package:provider/models/provider_order_model.dart';
import 'package:provider/services/auth_service.dart' as provider_auth;

import 'request_fakes.dart';

import '../support/firebase_web_plugins_stub.dart'
    if (dart.library.js_interop) '../support/firebase_web_plugins.dart';

const _enabled = bool.fromEnvironment('RUN_REQUEST_EMULATOR_TESTS');
const _fullRules = bool.fromEnvironment('RUN_FULL_RULES_TESTS');
const _project = 'demo-seer-requests';
const _owner = {
  'Authorization': 'Bearer owner',
  'Content-Type': 'application/json',
};

/// Takes a Dart value; returns the matching Firestore REST value for fixture seeding.
Map<String, dynamic> _value(dynamic value) {
  if (value == null) return {'nullValue': null};
  if (value is String) return {'stringValue': value};
  if (value is bool) return {'booleanValue': value};
  if (value is DateTime) {
    return {'timestampValue': value.toUtc().toIso8601String()};
  }
  if (value is int) return {'integerValue': value.toString()};
  if (value is num) return {'doubleValue': value};
  if (value is List) {
    return {
      'arrayValue': {'values': value.map(_value).toList()},
    };
  }
  if (value is GeoPoint) {
    return {
      'geoPointValue': {
        'latitude': value.latitude,
        'longitude': value.longitude,
      },
    };
  }
  if (value is Map<String, dynamic>) {
    return {
      'mapValue': {'fields': value.map((k, v) => MapEntry(k, _value(v)))},
    };
  }
  throw ArgumentError('Unsupported test fixture value');
}

/// Takes a document path and fields; seeds only the local emulator as admin.
Future<void> _seed(String path, Map<String, dynamic> data) async {
  final response = await http.patch(
    Uri.parse(
      'http://127.0.0.1:8180/v1/projects/$_project/databases/(default)/documents/$path',
    ),
    headers: _owner,
    body: jsonEncode({'fields': data.map((k, v) => MapEntry(k, _value(v)))}),
  );
  expect(response.statusCode, 200, reason: response.body);
}

class _Client {
  /// Takes an app, auth and database; groups an isolated emulator-only session.
  _Client(this.app, this.auth, this.db);
  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseFirestore db;

  /// Takes no inputs; returns the current test provider uid.
  String get uid => auth.currentUser!.uid;

  /// Takes no inputs; returns the real Dart request gateway using this session.
  ProviderRequestModel get model => ProviderRequestModel(firestore: db);
}

/// Takes a unique name and verification flag; creates a local provider session.
Future<_Client> _client(
  String name, {
  bool verified = true,
  bool provider = true,
}) async {
  final app = await Firebase.initializeApp(
    name: name,
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      appId: '1:1234567890:web:requests',
      messagingSenderId: '1234567890',
      projectId: _project,
      authDomain: 'demo-seer-requests.firebaseapp.com',
    ),
  );
  final auth = FirebaseAuth.instanceFor(app: app);
  await auth.useAuthEmulator('127.0.0.1', 9199, automaticHostMapping: false);
  await auth.setPersistence(Persistence.NONE);
  final db = FirebaseFirestore.instanceFor(app: app);
  db.settings = const Settings(persistenceEnabled: false);
  db.useFirestoreEmulator('127.0.0.1', 8180);
  await auth.createUserWithEmailAndPassword(
    email: '$name@example.test',
    password: 'Emulator-test-password-123',
  );
  if (verified) {
    final response = await http.post(
      Uri.parse(
        'http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:update?key=demo-api-key',
      ),
      headers: _owner,
      body: jsonEncode({
        'localId': auth.currentUser!.uid,
        'emailVerified': true,
      }),
    );
    expect(response.statusCode, 200, reason: response.body);
    await auth.currentUser!.reload();
    await auth.currentUser!.getIdToken(true);
  }
  if (provider) {
    await _seed('providers/${auth.currentUser!.uid}', {'status': 'approved'});
  }
  return _Client(app, auth, db);
}

/// Takes a response future; returns whether its transaction succeeded.
Future<bool> _wins(Future<void> decision) async {
  try {
    await decision;
    return true;
  } catch (_) {
    return false;
  }
}

/// Takes no inputs; registers actual Dart transaction and security-rule tests.
void main() {
  if (!_enabled) {
    test(
      'request transactions and security rules',
      () {},
      skip:
          'Requires local demo emulators and RUN_REQUEST_EMULATOR_TESTS=true.',
    );
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client first;
  late _Client second;
  late _Client outsider;
  late String orderId;
  late Map<String, dynamic> data;
  final runId = DateTime.now().microsecondsSinceEpoch;
  var sequence = 0;
  final denied = throwsA(
    isA<FirebaseException>().having((e) => e.code, 'code', 'permission-denied'),
  );

  setUpAll(() async {
    if (!kIsWeb) throw StateError('Use --platform chrome for emulator tests.');
    registerFirebaseWebPlugins();
    first = await _client('first-$runId');
    second = await _client('second-$runId');
    outsider = await _client('outside-$runId');
  });
  setUp(() async {
    orderId = 'request-$runId-${sequence++}';
    final now = DateTime.now();
    data = {
      'status': 'pending',
      'providerId': null,
      'candidateProviderIds': [first.uid, second.uid],
      'rejectedBy': <String>[],
      'expiresAt': now.add(const Duration(minutes: 2)),
      'createdAt': now,
      'customerId': 'customer-test',
      'customerName': 'Test Customer',
      'customerPhone': '0500000000',
      'estimatedPrice': 150,
      'pickupLocation': const GeoPoint(24.7, 46.6),
    };
    await _seed('orders/$orderId', data);
  });
  tearDownAll(() async {
    for (final client in [first, second, outsider]) {
      await client.auth.signOut();
      await client.db.terminate();
      await client.app.delete();
    }
  });

  test(
    'candidate snapshots query succeeds and excludes unrelated orders',
    () async {
      await _seed('orders/unrelated-$runId', {
        ...data,
        'candidateProviderIds': [outsider.uid],
      });
      final orders = await first.model
          .watchCandidates(first.uid)
          .firstWhere((orders) => orders.any((order) => order.id == orderId));
      expect(orders.any((order) => order.id == 'unrelated-$runId'), isFalse);
      expect(
        orders.firstWhere((order) => order.id == orderId).candidateProviderIds,
        contains(first.uid),
      );
    },
  );

  test(
    'accept writes only status, own providerId and a server acceptedAt',
    () async {
      await first.model.accept(orderId, first.uid);
      final saved =
          (await first.db
                  .doc('orders/$orderId')
                  .get(const GetOptions(source: Source.server)))
              .data()!;
      expect(saved['status'], 'accepted');
      expect(saved['providerId'], first.uid);
      expect(saved['acceptedAt'], isA<Timestamp>());
      expect(saved['estimatedPrice'], 150);
      expect(saved['rejectedBy'], isEmpty);
      expect(
        (saved['expiresAt'] as Timestamp).toDate().toUtc(),
        (data['expiresAt'] as DateTime).toUtc(),
      );
    },
  );

  test('two simultaneous accepts have exactly one winner', () async {
    final results = await Future.wait([
      _wins(first.model.accept(orderId, first.uid)),
      _wins(second.model.accept(orderId, second.uid)),
    ]);
    expect(results.where((won) => won), hasLength(1));
    final saved = (await first.db.doc('orders/$orderId').get()).data()!;
    expect(saved['status'], 'accepted');
    expect(saved['providerId'], results.first ? first.uid : second.uid);
  });

  test(
    'one rejection stays pending and the other provider may accept',
    () async {
      await first.model.reject(orderId, first.uid);
      final rejected = (await second.db.doc('orders/$orderId').get()).data()!;
      expect(rejected['status'], 'pending');
      expect(rejected['rejectedBy'], [first.uid]);
      await expectLater(
        first.model.accept(orderId, first.uid),
        throwsA(isA<RequestUnavailable>()),
      );
      await second.model.accept(orderId, second.uid);
      expect(
        (await second.db.doc('orders/$orderId').get()).data()!['providerId'],
        second.uid,
      );
    },
  );

  test(
    'concurrent rejections retain both ids and reject only after the last',
    () async {
      await Future.wait([
        first.model.reject(orderId, first.uid),
        second.model.reject(orderId, second.uid),
      ]);
      final saved = (await first.db.doc('orders/$orderId').get()).data()!;
      expect(saved['status'], 'rejected');
      expect(saved['rejectedBy'], unorderedEquals([first.uid, second.uid]));
      expect(saved.containsKey('acceptedAt'), isFalse);
    },
  );

  test('last sequential rejection changes pending to rejected', () async {
    await first.model.reject(orderId, first.uid);
    await second.model.reject(orderId, second.uid);
    final saved = (await first.db.doc('orders/$orderId').get()).data()!;
    expect(saved['status'], 'rejected');
    expect(saved['rejectedBy'], unorderedEquals([first.uid, second.uid]));
  });

  test('expired pending order is untouched by accept and reject', () async {
    await _seed('orders/$orderId', {
      ...data,
      'expiresAt': DateTime.now().subtract(const Duration(seconds: 1)),
    });
    await expectLater(
      first.model.accept(orderId, first.uid),
      throwsA(isA<RequestUnavailable>()),
    );
    await expectLater(
      first.model.reject(orderId, first.uid),
      throwsA(isA<RequestUnavailable>()),
    );
    final saved = (await first.db.doc('orders/$orderId').get()).data()!;
    expect(saved['status'], 'pending');
    expect(saved['rejectedBy'], isEmpty);
  });

  test('customer cancellation prevents subsequent responses', () async {
    await _seed('orders/$orderId', {...data, 'status': 'cancelled'});
    await expectLater(
      first.model.accept(orderId, first.uid),
      throwsA(isA<RequestUnavailable>()),
    );
    await expectLater(
      first.model.reject(orderId, first.uid),
      throwsA(isA<RequestUnavailable>()),
    );
    expect(
      (await first.db.doc('orders/$orderId').get()).data()!['status'],
      'cancelled',
    );
  });

  test(
    'server deadline rejects acceptance even with a slow provider clock',
    () async {
      await _seed('orders/$orderId', {
        ...data,
        'expiresAt': DateTime.now().subtract(const Duration(seconds: 5)),
      });
      final skewed = ProviderRequestModel(
        firestore: first.db,
        now: () => DateTime.now().subtract(const Duration(minutes: 10)),
      );
      await expectLater(skewed.accept(orderId, first.uid), denied);
      expect(
        (await first.db.doc('orders/$orderId').get()).data()!['status'],
        'pending',
      );
    },
  );

  test(
    'non-candidate cannot read or modify another provider request',
    () async {
      await expectLater(outsider.db.doc('orders/$orderId').get(), denied);
      await expectLater(
        outsider.db.doc('orders/$orderId').update({
          'status': 'accepted',
          'providerId': outsider.uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        }),
        denied,
      );
      await expectLater(first.db.collection('orders').get(), denied);
    },
  );

  test('rules deny unrelated fields, fake timestamps and accepting for someone else', () async {
    final ref = first.db.doc('orders/$orderId');
    final accept = {
      'status': 'accepted',
      'providerId': first.uid,
      'acceptedAt': FieldValue.serverTimestamp(),
    };
    for (final extra in <Map<String, dynamic>>[
      {'estimatedPrice': 1},
      {'customerId': first.uid},
      {
        'candidateProviderIds': [first.uid],
      },
      {'note': 'changed'},
      {
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 1)),
        ),
      },
      {'acceptedAt': Timestamp.fromDate(DateTime.now())},
      {'providerId': second.uid},
    ]) {
      await expectLater(
        ref.update({...accept, ...extra}),
        denied,
        reason: '$extra',
      );
    }
  });

  test('provider cannot auto-cancel or mark all rejected on another provider behalf', () async {
    final ref = first.db.doc('orders/$orderId');
    await expectLater(ref.update({'status': 'autoCancelled'}), denied);
    await expectLater(
      ref.update({
        'status': 'rejected',
        'rejectedBy': FieldValue.arrayUnion([first.uid, second.uid]),
      }),
      denied,
    );
    await expectLater(
      ref.update({
        'status': 'rejected',
        'rejectedBy': FieldValue.arrayUnion([first.uid]),
      }),
      denied,
    );
    await expectLater(
      ref.update({
        'rejectedBy': FieldValue.arrayUnion([second.uid]),
      }),
      denied,
    );
  });

  test(
    'a rejected provider cannot undo rejection or claim the same order',
    () async {
      await first.model.reject(orderId, first.uid);
      final ref = first.db.doc('orders/$orderId');
      await expectLater(ref.update({'rejectedBy': []}), denied);
      await expectLater(
        ref.update({
          'status': 'accepted',
          'providerId': first.uid,
          'acceptedAt': FieldValue.serverTimestamp(),
        }),
        denied,
      );
    },
  );

  test('GPS gateway saves only the current provider location for matching', () async {
    const point = GeoPoint(24.7136, 46.6753);
    await ProviderLocationModel(firestore: first.db)
        .saveCurrentLocation(first.uid, point);
    final response = await http.get(
      Uri.parse(
        'http://127.0.0.1:8180/v1/projects/$_project/databases/(default)/documents/providers/${first.uid}',
      ),
      headers: _owner,
    );
    expect(response.statusCode, 200);
    final fields = jsonDecode(response.body)['fields'] as Map;
    expect(fields['status']['stringValue'], 'approved');
    expect(
      fields['currentLocation']['geoPointValue']['latitude'],
      point.latitude,
    );
    await expectLater(
      ProviderLocationModel(firestore: first.db)
          .saveCurrentLocation(second.uid, point),
      denied,
    );
    await expectLater(
      first.db.doc('providers/${first.uid}').update({
        'currentLocation': point,
        'status': 'rejected',
      }),
      denied,
    );
    await expectLater(
      first.db.doc('providers/${first.uid}').update({
        'currentLocation': 'not-a-location',
      }),
      denied,
    );
  });

  test('approved status is required even for a candidate', () async {
    await _seed('providers/${first.uid}', {'status': 'rejected'});
    await expectLater(
      first.db
          .doc('orders/$orderId')
          .get(const GetOptions(source: Source.server)),
      denied,
    );
    await _seed('providers/${first.uid}', {'status': 'approved'});
  });

  if (_fullRules) {
    group('complete application rules', () {
      late _Client customer;
      late _Client admin;
      late _Client applicant;
      late _Client guest;
      const point = GeoPoint(24.7, 46.6);
      const vehicle = {
        'brand': 'Toyota',
        'model': 'Camry',
        'year': 2022,
        'color': 'white',
        'plateNumberArabic': '1234 أ ب د',
        'plateNumberLatin': '1234 A B D',
      };

      // Closing idle channels between scenarios avoids Chrome's per-host HTTP
      // connection limit across independent Firebase app instances.
      setUp(() async {
        for (final client in [
          first,
          second,
          outsider,
          customer,
          admin,
          applicant,
          guest,
        ]) {
          await client.db.disableNetwork();
          await client.db.enableNetwork();
        }
      });
      tearDown(() async {
        for (final client in [
          first,
          second,
          outsider,
          customer,
          admin,
          applicant,
          guest,
        ]) {
          await client.db.disableNetwork();
        }
      });

      setUpAll(() async {
        customer = await _client('customer-$runId', provider: false);
        admin = await _client('admin-$runId', provider: false);
        applicant = await _client(
          'applicant-$runId',
          provider: false,
          verified: false,
        );
        guest = await _client('guest-$runId', provider: false);
        await guest.auth.signOut();
        await _seed('admins/${admin.uid}', {'role': 'admin'});
        await _seed('customers/${customer.uid}', {
          'firstName': 'Test',
          'lastName': 'Customer',
          'phone': '0500000000',
          'email': customer.auth.currentUser!.email!,
        });
        await _seed('customers/${customer.uid}/vehicles/car-1', vehicle);
        await _seed('lookup_data/vehicles', {'brands': <String>[]});
        await _seed('lookup_data/service_prices', {'battery': 80});
        await _seed('lookup_data/private', {'secret': 'test'});
      });
      tearDownAll(() async {
        for (final client in [customer, admin, applicant, guest]) {
          await client.auth.signOut();
          await client.db.terminate();
          await client.app.delete();
        }
      });

      /// Takes no inputs; creates an order through the real shared order gateway.
      Future<String> createCustomerOrder() => OrderModel(firestore: customer.db)
          .createOrder(
            requestFixture(
              DateTime.now(),
              overrides: {
                'customerId': customer.uid,
                'candidateProviderIds': [first.uid, second.uid],
              },
            ),
          );

      test('signed-out users only read public catalogues, never profiles or orders', () async {
        for (final id in ['vehicles', 'service_prices']) {
          expect((await guest.db.doc('lookup_data/$id').get()).exists, isTrue);
          await expectLater(
            guest.db.doc('lookup_data/$id').update({'x': true}),
            denied,
          );
        }
        for (final path in [
          'providers/${first.uid}',
          'customers/${customer.uid}',
          'admins/${admin.uid}',
          'orders/$orderId',
          'lookup_data/private',
        ]) {
          await expectLater(guest.db.doc(path).get(), denied, reason: path);
          await expectLater(guest.db.doc(path).delete(), denied, reason: path);
        }
        await expectLater(
          guest.db.doc('unknown/test').set({'x': true}),
          denied,
        );
      });

      test(
        'customer registration, own edits and vehicle CRUD remain allowed',
        () async {
          final fresh = await _client(
            'new-customer-$runId',
            provider: false,
            verified: false,
          );
          try {
            final ref = fresh.db.doc('customers/${fresh.uid}');
            expect((await ref.get()).exists, isFalse);
            await ref.set({
              'firstName': 'Shams',
              'lastName': 'Test',
              'phone': '0500000000',
              'email': fresh.auth.currentUser!.email,
              'createdAt': FieldValue.serverTimestamp(),
            });
            await ref.update({'firstName': 'Updated'});
            await expectLater(ref.update({'role': 'admin'}), denied);
            final car = ref.collection('vehicles').doc('one');
            await car.set(vehicle);
            await car.update({'color': 'blue'});
            expect((await ref.collection('vehicles').get()).size, 1);
            await car.delete();
            await expectLater(
              customer.db.doc('customers/${fresh.uid}').get(),
              denied,
            );
            await expectLater(
              customer.db.doc('customers/${fresh.uid}').update({'phone': '0'}),
              denied,
            );
            await expectLater(
              customer.db
                  .doc('customers/${fresh.uid}/vehicles/one')
                  .set(vehicle),
              denied,
            );
          } finally {
            await fresh.auth.signOut();
            await fresh.db.terminate();
            await fresh.app.delete();
          }
        },
      );

      test(
        'provider submits after email verification and only admin approves',
        () async {
          final ref = applicant.db.doc('providers/${applicant.uid}');
          final registration = {
            'firstName': 'Test',
            'lastName': 'Provider',
            'phone': '0500000000',
            'email': applicant.auth.currentUser!.email,
            'nationalId': '1000000000',
            'vehicleType': 'car',
            'vehicleBrand': 'Toyota',
            'vehicleModel': 'Camry',
            'vehicleYear': '2022',
            'vehicleColor': 'white',
            'licenseNumber': '123',
            'plateNumberArabic': '1234 أ ب د',
            'plateNumberLatin': '1234 A B D',
            'servicesOffered': <String, dynamic>{},
            'status': 'unverified',
            'createdAt': FieldValue.serverTimestamp(),
          };
          expect((await ref.get()).exists, isFalse);
          await expectLater(
            ref.set({...registration, 'status': 'approved'}),
            denied,
          );
          await expectLater(
            ref.set({...registration, 'role': 'admin'}),
            denied,
          );
          await ref.set(registration);
          await expectLater(
            ref.update({
              'status': 'pending',
              'submittedAt': FieldValue.serverTimestamp(),
            }),
            denied,
          );
          final response = await http.post(
            Uri.parse(
              'http://127.0.0.1:9199/identitytoolkit.googleapis.com/v1/accounts:update?key=demo-api-key',
            ),
            headers: _owner,
            body: jsonEncode({'localId': applicant.uid, 'emailVerified': true}),
          );
          expect(response.statusCode, 200);
          await provider_auth.AuthService(
            auth: applicant.auth,
            firestore: applicant.db,
          ).submitForReviewIfVerified();
          expect((await ref.get()).data()!['status'], 'pending');
          expect(
            (await admin.db
                    .collection('providers')
                    .where('status', isEqualTo: 'pending')
                    .orderBy('createdAt', descending: true)
                    .get())
                .docs
                .map((d) => d.id),
            contains(applicant.uid),
          );
          await expectLater(ref.update({'status': 'approved'}), denied);
          await admin.db.doc('providers/${applicant.uid}').update({
            'status': 'approved',
          });
          await ref.update({
            'phone': '0550000000',
            'servicesOffered': <String, dynamic>{},
          });
          await expectLater(ref.update({'rating': 5}), denied);
          await expectLater(
            ref.update({'createdAt': FieldValue.serverTimestamp()}),
            denied,
          );
        },
      );

      test(
        'admin reads users but cannot be provisioned or changed by any client',
        () async {
          expect(
            (await admin.db.doc('admins/${admin.uid}').get()).data()!['role'],
            'admin',
          );
          expect(
            (await customer.db.doc('admins/${customer.uid}').get()).exists,
            isFalse,
          );
          expect(
            (await admin.db.collection('customers').get()).docs,
            isNotEmpty,
          );
          expect(
            (await admin.db
                    .collection('providers')
                    .where('status', isEqualTo: 'approved')
                    .get())
                .docs,
            isNotEmpty,
          );
          for (final client in [customer, first, admin]) {
            await expectLater(
              client.db.doc('admins/${client.uid}').set({'role': 'admin'}),
              denied,
            );
            await expectLater(
              client.db.doc('admins/${admin.uid}').delete(),
              denied,
            );
          }
          await expectLater(customer.db.collection('customers').get(), denied);
        },
      );

      test('approved provider publishes GPS, availability and remains queryable for matching', () async {
        final ref = first.db.doc('providers/${first.uid}');
        await ref.update({'currentLocation': point});
        await ref.update({'isAvailable': true});
        final match = await customer.db
            .collection('providers')
            .where('status', isEqualTo: 'approved')
            .where('isAvailable', isEqualTo: true)
            .get();
        expect(match.docs.map((d) => d.id), contains(first.uid));
        await ref.update({'isAvailable': false});
        expect(
          (await customer.db.doc('providers/${first.uid}').get()).exists,
          isTrue,
        );
        await expectLater(
          customer.db.doc('providers/${first.uid}').update({
            'currentLocation': point,
          }),
          denied,
        );
        await expectLater(
          first.db.doc('providers/${second.uid}').get(),
          denied,
        );
        await expectLater(ref.update({'isAvailable': 'yes'}), denied);
      });

      test('real order creation, customer snapshots, acceptance and provider completion work', () async {
        final id = await createCustomerOrder();
        final listed = await customer.db
            .collection('orders')
            .where('customerId', isEqualTo: customer.uid)
            .snapshots()
            .firstWhere((snapshot) => snapshot.docs.any((o) => o.id == id));
        expect(
          listed.docs.firstWhere((o) => o.id == id).data()['status'],
          'pending',
        );
        await first.model.accept(id, first.uid);
        final active = ProviderOrderModel(firestore: first.db);
        expect(
          await active
              .watchCurrentOrder(first.uid)
              .firstWhere((o) => o != null),
          isNotNull,
        );
        await expectLater(
          second.db.doc('orders/$id').update({
            'status': 'onTheWay',
            'onTheWayAt': FieldValue.serverTimestamp(),
          }),
          denied,
        );
        await active.advanceStatus(
          orderId: id,
          from: 'accepted',
          to: 'onTheWay',
        );
        await active.advanceStatus(
          orderId: id,
          from: 'onTheWay',
          to: 'arrived',
        );
        await active.advanceStatus(
          orderId: id,
          from: 'arrived',
          to: 'inProgress',
        );
        await active.completeWithPayment(orderId: id, amount: 150);
        expect(await active.sumEarnings(first.uid), greaterThanOrEqualTo(150));
        expect(
          await active.countCompletedToday(first.uid),
          greaterThanOrEqualTo(1),
        );
        expect(
          (await customer.db
                  .doc('orders/$id')
                  .snapshots()
                  .firstWhere((o) => o.data()?['status'] == 'completed'))
              .data()!['paymentConfirmed'],
          isTrue,
        );
        await expectLater(
          customer.db.doc('orders/$id').update({'status': 'pending'}),
          denied,
        );
        await expectLater(first.db.doc('orders/$id').delete(), denied);
      });

      test('customer cannot forge acceptance, ownership, price edits or response deadlines', () async {
        final id = await createCustomerOrder();
        final ref = customer.db.doc('orders/$id');
        for (final edit in [
          {
            'providerId': first.uid,
            'status': 'accepted',
            'acceptedAt': FieldValue.serverTimestamp(),
          },
          {'customerId': second.uid},
          {'estimatedPrice': 1},
          {
            'candidateProviderIds': [outsider.uid],
          },
          {
            'expiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 1)),
            ),
          },
        ]) {
          await expectLater(ref.update(edit), denied, reason: '$edit');
        }
        final payload = (await ref.get()).data()!;
        for (final extra in [
          {'status': 'accepted'},
          {'customerId': first.uid},
          {'paymentConfirmed': true},
          {
            'expiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(hours: 1)),
            ),
          },
          {'acceptedAt': FieldValue.serverTimestamp()},
          {'vehicleId': 'someone-elses-car'},
        ]) {
          await expectLater(
            customer.db.collection('orders').add({
              ...payload,
              'createdAt': FieldValue.serverTimestamp(),
              ...extra,
            }),
            denied,
            reason: '$extra',
          );
        }
        await expectLater(outsider.db.doc('orders/$id').get(), denied);
        await expectLater(
          first.db.collection('orders').add({
            ...payload,
            'customerId': first.uid,
            'createdAt': FieldValue.serverTimestamp(),
          }),
          denied,
        );
      });

      test('customer cancellation payload works for pending and recently accepted orders', () async {
        final pendingId = await createCustomerOrder();
        await customer.db.doc('orders/$pendingId').update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        expect(
          (await customer.db.doc('orders/$pendingId').get()).data()!['status'],
          'cancelled',
        );
        final acceptedId = await createCustomerOrder();
        await second.model.accept(acceptedId, second.uid);
        await customer.db.doc('orders/$acceptedId').update({
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        expect(
          (await customer.db.doc('orders/$acceptedId').get()).data()!['status'],
          'cancelled',
        );
      });

      test('server time blocks early auto-cancellation and late accepted cancellation', () async {
        final id = await createCustomerOrder();
        final ref = customer.db.doc('orders/$id');
        await expectLater(
          ref.update({
            'status': 'autoCancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          }),
          denied,
        );
        await _seed('orders/$id', {
          ...data,
          'customerId': customer.uid,
          'status': 'accepted',
          'providerId': first.uid,
          'acceptedAt': DateTime.now().subtract(const Duration(minutes: 3)),
        });
        await expectLater(
          ref.update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          }),
          denied,
        );
        await _seed('orders/$id', {
          ...data,
          'customerId': customer.uid,
          'expiresAt': DateTime.now().subtract(const Duration(seconds: 1)),
        });
        await ref.update({
          'status': 'autoCancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        expect((await ref.get()).data()!['status'], 'autoCancelled');
      });

      test('provider cannot skip lifecycle steps, fake timestamps or change unrelated fields', () async {
        final id = await createCustomerOrder();
        await first.model.accept(id, first.uid);
        final ref = first.db.doc('orders/$id');
        for (final edit in [
          {'status': 'arrived', 'arrivedAt': FieldValue.serverTimestamp()},
          {
            'status': 'onTheWay',
            'onTheWayAt': Timestamp.fromDate(DateTime(2020)),
          },
          {
            'status': 'onTheWay',
            'onTheWayAt': FieldValue.serverTimestamp(),
            'estimatedPrice': 0,
          },
          {
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'paymentConfirmed': true,
          },
        ]) {
          await expectLater(ref.update(edit), denied, reason: '$edit');
        }
      });
    });
  }
}
