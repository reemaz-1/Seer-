import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/controllers/provider_requests_controller.dart';
import 'package:provider/models/provider_request_model.dart';

import 'request_fakes.dart';

/// Takes no inputs; registers controller/contract regressions for #37–#39.
void main() {
  var disposed = false;
  late DateTime now;
  late FakeRequests repository;
  late FakeLocation location;
  late ProviderRequestsController controller;

  // Takes no inputs; releases owned timers once before widget invariant checks.
  void disposeController() {
    if (!disposed) {
      disposed = true;
      controller.dispose();
    }
  }

  setUp(() {
    disposed = false;
    now = DateTime.utc(2026, 10, 9, 12);
    repository = FakeRequests();
    location = FakeLocation();
    controller = ProviderRequestsController(
      providerId: 'p1',
      repository: repository,
      location: location,
      now: () => now,
    );
  });
  tearDown(() async {
    disposeController();
    await repository.stream.close();
    await location.stream.close();
  });

  test('both apps retain exactly the same order contract file', () {
    expect(
      File('lib/models/order.dart').readAsStringSync(),
      File('../customer/lib/models/order.dart').readAsStringSync(),
    );
  });

  test('eligibility fails closed for all unavailable states', () {
    expect(
      RequestEligibility.canRespond(requestFixture(now), 'p1', now),
      isTrue,
    );
    for (final overrides in <Map<String, dynamic>>[
      {'status': 'accepted'},
      {'status': 'cancelled'},
      {'status': 'autoCancelled'},
      {'status': 'rejected'},
      {'providerId': 'p2'},
      {'expiresAt': null},
      {'expiresAt': Timestamp.fromDate(now)},
      {
        'expiresAt': Timestamp.fromDate(
          now.subtract(const Duration(seconds: 1)),
        ),
      },
      {
        'candidateProviderIds': ['p2'],
      },
      {
        'rejectedBy': ['p1'],
      },
    ]) {
      expect(
        RequestEligibility.canRespond(
          requestFixture(now, overrides: overrides),
          'p1',
          now,
        ),
        isFalse,
        reason: '$overrides',
      );
    }
  });

  testWidgets('filters snapshots and expires without another server event', (
    tester,
  ) async {
    controller.start();
    repository.stream.add([
      requestFixture(now, id: 'later'),
      requestFixture(
        now,
        id: 'soon',
        overrides: {
          'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 1))),
        },
      ),
      requestFixture(
        now,
        id: 'hidden',
        overrides: {
          'rejectedBy': ['p1'],
        },
      ),
    ]);
    var notifications = 0;
    controller.addListener(() => notifications++);
    expect(controller.availableRequests.map((o) => o.id), ['soon', 'later']);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(notifications, greaterThan(0));
    expect(controller.availableRequests.map((o) => o.id), ['later']);
    disposeController();
  });

  test('countdown uses existing expiry, not screen opening time', () {
    final order = requestFixture(
      now,
      overrides: {
        'expiresAt': Timestamp.fromDate(now.add(const Duration(seconds: 65))),
      },
    );
    expect(controller.countdown(order), '1:05');
    expect(controller.progress(order), closeTo(65 / 120, 0.001));
    now = now.add(const Duration(milliseconds: 64500));
    expect(controller.countdown(order), '0:01');
    now = now.add(const Duration(milliseconds: 500));
    expect(controller.countdown(order), '0:00');
    expect(controller.canRespond(order), isFalse);
  });

  test('one decimal km reflects provider GPS updates', () async {
    controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(controller.distanceText(requestFixture(now)), matches(r'^1\.0 كم$'));
    location.stream.add(const GeoPoint(24.7136, 46.6753));
    expect(controller.distanceText(requestFixture(now)), '0.0 كم');
  });

  test(
    'permission denial preserves requests and gives a consumable Arabic error',
    () async {
      location.failure = StateError('اسمح بالوصول إلى الموقع');
      controller.start();
      repository.stream.add([requestFixture(now)]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.availableRequests, hasLength(1));
      expect(controller.takeError(), 'اسمح بالوصول إلى الموقع');
      expect(controller.takeError(), isNull);
      expect(controller.distanceText(requestFixture(now)), 'المسافة غير متاحة');
    },
  );

  test('duplicate taps cannot launch a second transaction', () async {
    controller.start();
    repository.stream.add([requestFixture(now)]);
    repository.pending = Completer<void>();
    final first = controller.accept('request-1');
    expect(await controller.accept('request-1'), isNotNull);
    expect(repository.accepts, 1);
    repository.pending!.complete();
    expect(await first, isNull);
    expect(controller.availableRequests, isEmpty);
  });

  test('transaction race failure removes stale request', () async {
    controller.start();
    repository.stream.add([requestFixture(now)]);
    repository.failure = const RequestUnavailable();
    expect(
      await controller.accept('request-1'),
      ProviderRequestsController.unavailableMessage,
    );
    expect(controller.availableRequests, isEmpty);
  });

  test('offline failure does not optimistically hide a request', () async {
    controller.start();
    repository.stream.add([requestFixture(now)]);
    repository.failure = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    expect(await controller.accept('request-1'), contains('الاتصال'));
    expect(controller.availableRequests, hasLength(1));
    expect(controller.isBusy('request-1'), isFalse);
  });

  test('expiry blocks both decisions before any repository write', () async {
    controller.start();
    repository.stream.add([requestFixture(now)]);
    now = now.add(const Duration(minutes: 2));
    expect(
      await controller.accept('request-1'),
      ProviderRequestsController.unavailableMessage,
    );
    expect(
      await controller.reject('request-1'),
      ProviderRequestsController.unavailableMessage,
    );
    expect(repository.accepts + repository.rejects, 0);
  });

  test('declining hides the request for this provider immediately', () async {
    controller.start();
    repository.stream.add([requestFixture(now)]);
    expect(await controller.reject('request-1'), isNull);
    expect(repository.rejects, 1);
    expect(controller.availableRequests, isEmpty);
  });
}
