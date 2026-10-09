import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/controllers/provider_availability_controller.dart';
import 'package:provider/models/service_provider.dart';
import 'package:provider/services/auth_service.dart';
import 'package:provider/services/provider_location_service.dart';

class _Auth extends Mock implements AuthService {}

class _User extends Mock implements User {}

class _Profiles extends Mock implements ProviderModel {}

class _Location extends Mock implements ProviderLocationSource {}

/// Takes no inputs; tests that enabling availability waits for a persisted GPS fix.
void main() {
  late _Auth auth;
  late _User user;
  late _Profiles profiles;
  late _Location location;
  late ProviderAvailabilityController controller;
  setUp(() {
    auth = _Auth();
    user = _User();
    profiles = _Profiles();
    location = _Location();
    when(() => auth.currentUser).thenReturn(user);
    when(() => user.uid).thenReturn('p1');
    when(() => profiles.updateProvider(any(), any())).thenAnswer((_) async {});
    controller = ProviderAvailabilityController(
      auth,
      model: profiles,
      location: location,
    );
  });
  test(
    'availability is enabled only after location persistence completes',
    () async {
      final pending = Completer<GeoPoint>();
      when(() => location.current()).thenAnswer((_) => pending.future);
      final update = controller.updateAvailability(true);
      verifyNever(() => profiles.updateProvider(any(), any()));
      pending.complete(const GeoPoint(24.7, 46.6));
      await update;
      verify(() => profiles.updateProvider('p1', {'isAvailable': true}))
          .called(1);
    },
  );
  test('failed location does not advertise provider availability', () async {
    when(() => location.current()).thenThrow(StateError('location denied'));
    await expectLater(controller.updateAvailability(true), throwsStateError);
    verifyNever(() => profiles.updateProvider(any(), any()));
  });
  test(
    'disabling availability needs no location permission or GPS call',
    () async {
      await controller.updateAvailability(false);
      verifyNever(() => location.current());
      verify(() => profiles.updateProvider('p1', {'isAvailable': false}))
          .called(1);
    },
  );
  test(
    'signed-out provider cannot publish location or enable availability',
    () async {
      when(() => auth.currentUser).thenReturn(null);
      await expectLater(
        controller.updateAvailability(true),
        throwsA(isA<AuthException>()),
      );
      verifyNever(() => location.current());
      verifyNever(() => profiles.updateProvider(any(), any()));
    },
  );
}
