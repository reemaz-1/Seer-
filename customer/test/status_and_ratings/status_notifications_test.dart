import 'dart:async';

import 'package:customer/controllers/customer_notifications_controller.dart';
import 'package:customer/models/customer_notification.dart';
import 'package:customer/models/order_status_notification.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_store.dart';
// Exercise the separate provider app through its real transition writers.
// ignore_for_file: avoid_relative_lib_imports
import '../../../provider/lib/models/provider_order_model.dart';
import '../../../provider/lib/models/provider_request_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

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
    'real provider status writer persists the event with the status',
    () async {
      final store = MemoryStore();
      store.data['orders/o1'] = {'customerId': 'c1', 'status': 'accepted'};
      await ProviderOrderModel(firestore: store)
          .advanceStatus(orderId: 'o1', from: 'accepted', to: 'onTheWay');
      expect(store.data['orders/o1']!['status'], 'onTheWay');
      expect(store.data['notifications/o1_onTheWay']!['recipientId'], 'c1');
      await expectLater(
        ProviderOrderModel(firestore: store)
            .advanceStatus(orderId: 'o1', from: 'accepted', to: 'onTheWay'),
        throwsStateError,
      );
      expect(
        store.written.where((p) => p == 'notifications/o1_onTheWay'),
        hasLength(1),
      );
    },
  );
  test(
    'acceptance writes a customer notice and claims the provider atomically',
    () async {
      final store = MemoryStore();
      store.data['orders/o1'] = {
        'customerId': 'c1',
        'status': 'pending',
        'candidateProviderIds': ['p1'],
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 1)),
        ),
      };
      store.data['providers/p1'] = {};
      await ProviderRequestModel(firestore: store).accept('o1', 'p1');
      expect(store.data['orders/o1']!['status'], 'accepted');
      expect(store.data['notifications/o1_accepted']!['recipientId'], 'c1');
      expect(store.data['providers/p1']!['activeOrderId'], 'o1');
    },
  );
  test(
    'completion persists the payment and customer notice together',
    () async {
      final store = MemoryStore();
      store.data['orders/o1'] = {
        'customerId': 'c1',
        'providerId': 'p1',
        'status': 'inProgress',
      };
      store.data['providers/p1'] = {'activeOrderId': 'o1'};
      await ProviderOrderModel(firestore: store)
          .completeWithPayment(orderId: 'o1', amount: 150);
      expect(store.data['orders/o1']!['status'], 'completed');
      expect(store.data['orders/o1']!['paymentConfirmed'], isTrue);
      expect(store.data['notifications/o1_completed']!['recipientId'], 'c1');
    },
  );
  test('only the final rejection notifies the customer', () async {
    final store = MemoryStore();
    store.data['orders/o1'] = {
      'customerId': 'c1',
      'status': 'pending',
      'candidateProviderIds': ['p1', 'p2'],
      'rejectedBy': ['p1'],
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 1)),
      ),
    };
    await ProviderRequestModel(firestore: store).reject('o1', 'p2');
    expect(store.data['orders/o1']!['status'], 'rejected');
    expect(store.data['notifications/o1_rejected']!['recipientId'], 'c1');
  });
}
