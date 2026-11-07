import 'package:flutter_test/flutter_test.dart';

import 'package:admin/models/admin_users_model.dart';
import 'support/memory_store.dart';

void main() {
  for (final type in ['customer', 'provider']) {
    test(
      'suspending $type cancels eligible orders and notifies counterpart',
      () async {
        final store = MemoryStore();
        store.data['customers/c1'] = {'isSuspended': false};
        store.data['providers/p1'] = {
          'isSuspended': false,
          'isAvailable': true,
          'activeOrderId': 'o1',
          'rating': 4.5,
        };
        store.data['orders/o1'] = {
          'customerId': 'c1',
          'providerId': 'p1',
          'status': 'accepted',
        };
        final user = AdminUserData.fromMap(
          type == 'customer' ? 'c1' : 'p1',
          type,
          {},
        );
        await AdminUsersModel.setSuspended(user, true, firestore: store);
        expect(store.data['orders/o1']!['status'], 'cancelled');
        expect(store.data['providers/p1']!.containsKey('activeOrderId'), false);
        expect(store.data['providers/p1']!['rating'], 4.5);
        final notices = store.data.entries
            .where((e) => e.key.startsWith('notifications/'))
            .map((e) => e.value)
            .toList();
        expect(notices, hasLength(1));
        expect(notices.single['recipientId'], type == 'customer' ? 'p1' : 'c1');
        expect(notices.single['type'], 'adminCancellation');
        expect(store.data['${type}s/${user.id}']!['isSuspended'], true);
        await AdminUsersModel.setSuspended(user, true, firestore: store);
        expect(
          store.written.where((p) => p.startsWith('notifications/')),
          hasLength(1),
        );
      },
    );
  }
  for (final status in ['onTheWay', 'arrived', 'inProgress']) {
    test('$status blocks suspension without any partial write', () async {
      final store = MemoryStore();
      store.data['customers/c1'] = {};
      store.data['orders/o1'] = {
        'customerId': 'c1',
        'providerId': 'p1',
        'status': status,
      };
      final user = AdminUserData.fromMap('c1', 'customer', {});
      await expectLater(
        AdminUsersModel.setSuspended(user, true, firestore: store),
        throwsA(isA<AdminSuspensionBlocked>()),
      );
      expect(store.written, isEmpty);
    });
  }
  test(
    'pending unassigned cancellation sends no notification to empty recipient',
    () async {
      final store = MemoryStore();
      store.data['customers/c1'] = {};
      store.data['orders/o1'] = {'customerId': 'c1', 'status': 'pending'};
      await AdminUsersModel.setSuspended(
        AdminUserData.fromMap('c1', 'customer', {}),
        true,
        firestore: store,
      );
      expect(store.data['orders/o1']!['status'], 'cancelled');
      expect(
        store.written.where((p) => p.startsWith('notifications/')),
        isEmpty,
      );
    },
  );
}
