import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:customer/models/customer_orders_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'memory_store.dart';

void main() {
  for (final accepted in [false, true]) {
    test(
      'self cancellation (${accepted ? "accepted" : "pending"}) never notifies customer',
      () async {
        final store = MemoryStore();
        store.data['orders/o1'] = {
          'customerId': 'c1',
          'status': accepted ? 'accepted' : 'pending',
          if (accepted) 'providerId': 'p1',
          'acceptedAt': Timestamp.now(),
        };
        store.data['providers/p1'] = {'activeOrderId': 'o1'};
        await CustomerOrdersModel(firestore: store).cancelOrder('o1');
        expect(store.data['orders/o1']!['status'], 'cancelled');
        final notices = store.data.entries
            .where((e) => e.key.startsWith('notifications/'))
            .map((e) => e.value)
            .toList();
        expect(notices, hasLength(accepted ? 1 : 0));
        if (accepted) {
          expect(notices.single['recipientId'], 'p1');
          expect(notices.single['type'], 'orderCancelled');
        }
        expect(notices.where((n) => n['recipientId'] == 'c1'), isEmpty);
        await expectLater(
          CustomerOrdersModel(firestore: store).cancelOrder('o1'),
          throwsStateError,
        );
        expect(
          store.written.where((p) => p.startsWith('notifications/')),
          hasLength(accepted ? 1 : 0),
        );
      },
    );
  }
  test(
    'expired pending order still emits exactly one customer event',
    () async {
      final store = MemoryStore();
      store.data['orders/o1'] = {
        'customerId': 'c1',
        'status': 'pending',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(seconds: 1)),
        ),
      };
      final model = CustomerOrdersModel(firestore: store);
      expect(await model.autoCancelIfExpired('o1'), true);
      expect(await model.autoCancelIfExpired('o1'), false);
      expect(
        store.data['notifications/o1_autoCancelled']!['recipientId'],
        'c1',
      );
      expect(
        store.written.where((p) => p.startsWith('notifications/')),
        hasLength(1),
      );
    },
  );
}
