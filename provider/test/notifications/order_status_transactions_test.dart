import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/models/provider_order_model.dart';
import 'package:provider/models/provider_request_model.dart';
import 'package:provider/models/order_status_notification.dart';

import '../support/memory_store.dart';

void main() {
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
  test(
    'all status steps preserve provider data and emit one event each',
    () async {
      final store = MemoryStore();
      store.data['orders/o1'] = {
        'customerId': 'c1',
        'providerId': 'p1',
        'status': 'accepted',
      };
      store.data['providers/p1'] = {
        'activeOrderId': 'o1',
        'rating': 4.2,
        'isAvailable': true,
      };
      final model = ProviderOrderModel(firestore: store);
      var from = 'accepted';
      for (final to in ['onTheWay', 'arrived', 'inProgress']) {
        await model.advanceStatus(orderId: 'o1', from: from, to: to);
        expect(store.data['notifications/o1_$to']!['status'], to);
        from = to;
      }
      await model.completeWithPayment(orderId: 'o1', amount: 150);
      expect(store.data['providers/p1']!.containsKey('activeOrderId'), false);
      expect(store.data['providers/p1']!['rating'], 4.2);
      expect(store.data['providers/p1']!['isAvailable'], true);
      expect(store.data['orders/o1']!['finalPrice'], 150);
      await expectLater(
        model.completeWithPayment(orderId: 'o1', amount: 150),
        throwsStateError,
      );
      expect(
        store.written.where((p) => p.startsWith('notifications/')).toSet(),
        hasLength(4),
      );
      expect(
        store.written.where((p) => p.startsWith('notifications/')),
        hasLength(4),
      );
    },
  );
  test('missing customer does not block acceptance or completion', () async {
    final store = MemoryStore();
    store.data['providers/p1'] = {};
    store.data['orders/o1'] = {
      'status': 'pending',
      'candidateProviderIds': ['p1'],
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(minutes: 1)),
      ),
    };
    await ProviderRequestModel(firestore: store).accept('o1', 'p1');
    final model = ProviderOrderModel(firestore: store);
    var from = 'accepted';
    for (final to in ['onTheWay', 'arrived', 'inProgress']) {
      await model.advanceStatus(orderId: 'o1', from: from, to: to);
      from = to;
    }
    await model.completeWithPayment(orderId: 'o1', amount: 150);
    expect(store.data['orders/o1']!['status'], 'completed');
    expect(store.written.where((p) => p.startsWith('notifications/')), isEmpty);
  });
  test(
    'non-final rejection leaves pending and sends no customer event',
    () async {
      final store = MemoryStore();
      store.data['orders/o1'] = {
        'customerId': 'c1',
        'status': 'pending',
        'candidateProviderIds': ['p1', 'p2'],
        'rejectedBy': <String>[],
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(minutes: 1)),
        ),
      };
      await ProviderRequestModel(firestore: store).reject('o1', 'p1');
      expect(store.data['orders/o1']!['status'], 'pending');
      expect(
        store.written.where((p) => p.startsWith('notifications/')),
        isEmpty,
      );
    },
  );
  test('invalid notification data is skipped without throwing', () async {
    final store = MemoryStore();
    await store.runTransaction<void>((tx) async {
      OrderStatusNotification.write(tx, store, 'o1', {}, 'completed');
    });
    expect(store.written, isEmpty);
  });
}
