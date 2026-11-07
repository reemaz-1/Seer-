import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/controllers/notification_controller.dart';
import 'package:provider/models/app_notification.dart';

/// Gives the controller a controllable list instead of Firestore.
class FakeNotifications extends NotificationModel {
  final stream = StreamController<List<AppNotification>>.broadcast(sync: true);

  @override
  Stream<List<AppNotification>> watch(String providerId) => stream.stream;

  @override
  Future<void> markRead(Iterable<String> ids) async {}
}

/// Takes an [id] and the time [now]; returns a request that can still be
/// answered for two more minutes.
AppNotification waitingRequest(String id, DateTime now) => AppNotification(
      id: id,
      type: AppNotification.typeNewRequest,
      orderId: 'order-$id',
      title: 'طلب جديد',
      body: 'تشغيل البطارية',
      read: false,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 2)),
    );

void main() {
  final now = DateTime(2026, 11, 7, 19);

  test('a waiting request found when the app opens is marked as first load',
      () async {
    final model = FakeNotifications();
    final controller =
        NotificationController(providerId: 'p1', model: model, now: () => now);
    final arrived = <AppNotification>[];
    controller
      ..onNew = arrived.add
      ..start();

    model.stream.add([waitingRequest('n1', now)]);

    expect(arrived.single.id, 'n1');
    expect(controller.lastArrivalOnFirstLoad, isTrue);
    controller.dispose();
    await model.stream.close();
  });

  test('a request that arrives later is not marked as first load', () async {
    final model = FakeNotifications();
    final controller =
        NotificationController(providerId: 'p1', model: model, now: () => now);
    final arrived = <AppNotification>[];
    controller
      ..onNew = arrived.add
      ..start();

    model.stream.add([]);
    model.stream.add([waitingRequest('n2', now)]);

    expect(arrived.single.id, 'n2');
    expect(controller.lastArrivalOnFirstLoad, isFalse);
    controller.dispose();
    await model.stream.close();
  });
}
