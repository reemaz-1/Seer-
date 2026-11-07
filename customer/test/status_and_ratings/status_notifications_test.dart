import 'dart:async';

import 'package:customer/controllers/customer_notifications_controller.dart';
import 'package:customer/models/customer_notification.dart';
import 'package:customer/models/order_status_notification.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_store.dart';

class NoticeModel extends CustomerNotificationModel {
  final events = StreamController<List<CustomerNotification>>.broadcast(
    sync: true,
  );
  final marked = <String>[];
  @override
  Stream<List<CustomerNotification>> watch(String uid) => events.stream;
  @override
  Future<void> markRead(String id) async => marked.add(id);
}

CustomerNotification notice(String id, {bool read = false}) =>
    CustomerNotification(
      id: id,
      orderId: 'o1',
      title: 'تم قبول طلبك',
      body: 'خدمة البطارية',
      read: read,
    );

void main() {
  test('inbox preserves history and announces new events only once', () async {
    final model = NoticeModel();
    final controller = CustomerNotificationsController(uid: 'c1', model: model);
    final announced = <String>[];
    controller.onNew = (item) => announced.add(item.id);
    controller.start();
    model.events.add([notice('old')]);
    expect(announced, isEmpty);
    model.events.add([notice('new'), notice('old')]);
    model.events.add([notice('new'), notice('old')]);
    expect(announced, ['new']);
    expect(controller.unreadCount, 2);
    await controller.markRead(notice('new'));
    expect(model.marked, ['new']);
    model.events.add([notice('new', read: true), notice('old')]);
    expect(controller.unreadCount, 1);
    model.events.addError(StateError('offline'));
    expect(controller.error, isNotNull);
    model.events.add([]);
    expect(controller.error, isNull);
    controller.dispose();
    await model.events.close();
  });
  test(
    'every customer-visible transition has a stable, atomic notice',
    () async {
      final store = MemoryStore();
      for (final status in OrderStatusNotification.messages.keys) {
        await store.runTransaction<void>((tx) async {
          OrderStatusNotification.write(tx, store, 'o1', {
            'customerId': 'c1',
          }, status);
        });
        final saved = store.data['notifications/o1_$status']!;
        expect(saved['recipientId'], 'c1');
        expect(saved['status'], status);
        expect(saved['read'], isFalse);
      }
    },
  );
  test(
    'two arrivals in one snapshot both announce, reconnect never repeats',
    () async {
      final model = NoticeModel();
      final controller = CustomerNotificationsController(
        uid: 'c1',
        model: model,
      );
      final announced = <String>[];
      controller.onNew = (item) => announced.add(item.id);
      controller.start();
      model.events.add([]);
      model.events.add([notice('completed'), notice('arrived')]);
      expect(announced, ['arrived', 'completed']);
      controller.start();
      await Future<void>.delayed(Duration.zero);
      model.events.add([notice('completed'), notice('arrived')]);
      expect(announced, ['arrived', 'completed']);
      controller.dispose();
      await model.events.close();
    },
  );
  test(
    'malformed legacy recipient skips notice without aborting transaction',
    () async {
      final store = MemoryStore();
      for (final customerId in [null, '', 123]) {
        await store.runTransaction<void>((tx) async {
          OrderStatusNotification.write(tx, store, 'o1', {
            'customerId': customerId,
          }, 'accepted');
          tx.set(store.collection('orders').doc('o1'), {'status': 'accepted'});
        });
      }
      expect(store.data.keys, ['orders/o1']);
    },
  );
}
