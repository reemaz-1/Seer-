import 'package:cloud_firestore/cloud_firestore.dart';

/// A user shown in the administrator's user-management screen.
class AdminUserData {
  final String id;
  final String type; // customer or provider
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String vehicleBrand;
  final String vehicleModel;
  final bool isSuspended;

  const AdminUserData({
    required this.id,
    required this.type,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.isSuspended,
    this.vehicleBrand = '',
    this.vehicleModel = '',
  });

  factory AdminUserData.fromMap(
    String id,
    String type,
    Map<String, dynamic> data,
  ) {
    String read(String key) => data[key]?.toString() ?? '';
    return AdminUserData(
      id: id,
      type: type,
      firstName: read('firstName'),
      lastName: read('lastName'),
      email: read('email'),
      phone: read('phone'),
      vehicleBrand: read('vehicleBrand'),
      vehicleModel: read('vehicleModel'),
      isSuspended: data['isSuspended'] == true,
    );
  }

  String get name => '$firstName $lastName'.trim();
}

class AdminOpenOrder {
  const AdminOpenOrder(this.id, this.status, this.customerId, this.providerId);
  final String id;
  final String status;
  final String customerId;
  final String providerId;
  bool get blocksSuspension =>
      const ['onTheWay', 'arrived', 'inProgress'].contains(status);
  bool get cancellable => const ['pending', 'accepted'].contains(status);
}

class AdminSuspensionBlocked implements Exception {
  const AdminSuspensionBlocked();
}

class AdminUsersModel {
  static Stream<List<AdminUserData>> streamCustomers() => FirebaseFirestore
      .instance
      .collection('customers')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AdminUserData.fromMap(doc.id, 'customer', doc.data()))
          .toList());

  // Keep approved providers in the list even after suspension, so the admin
  // can reactivate them. Approval and suspension are independent dimensions.
  static Stream<List<AdminUserData>> streamApprovedProviders() => FirebaseFirestore
      .instance
      .collection('providers')
      .where('status', isEqualTo: 'approved')
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AdminUserData.fromMap(doc.id, 'provider', doc.data()))
          .toList());

  static Future<List<AdminOpenOrder>> getOpenOrders(AdminUserData user, {bool includeExpiredPending = false}) async {
    final orders = FirebaseFirestore.instance.collection('orders');
    final query = user.type == 'customer'
        ? orders.where('customerId', isEqualTo: user.id)
        : orders.where('providerId', isEqualTo: user.id);
    final snapshot = await query.get();
    const open = {'pending', 'accepted', 'onTheWay', 'arrived', 'inProgress'};
    final now = DateTime.now();
    return snapshot.docs.where((d) {
      final data = d.data();
      if (!open.contains(data['status'])) return false;
      // An expired pending request is not CURRENT even if its stored status
      // was never auto-cancelled because the Customer app was closed.
      // Keep it when suspending so it can still be cleaned up safely.
      if (!includeExpiredPending && data['status'] == 'pending') {
        final expiry = data['expiresAt'];
        if (expiry is Timestamp && !expiry.toDate().isAfter(now)) return false;
      }
      return true;
    }).map((d) {
      final data = d.data();
      return AdminOpenOrder(
        d.id,
        (data['status'] ?? '').toString(),
        (data['customerId'] ?? '').toString(),
        (data['providerId'] ?? '').toString(),
      );
    }).toList();
  }

  static Future<void> setSuspended(AdminUserData user, bool suspended) async {
    if (user.id.isEmpty || !['customer', 'provider'].contains(user.type)) {
      throw ArgumentError('Invalid account identifier or account type');
    }
    final db = FirebaseFirestore.instance;
    final collection = user.type == 'customer' ? 'customers' : 'providers';
    final accountRef = db.collection(collection).doc(user.id);
    if (!suspended) {
      await accountRef.update({'isSuspended': false});
      return;
    }
    final preview = await getOpenOrders(user, includeExpiredPending: true);
    if (preview.any((o) => o.blocksSuspension)) {
      throw const AdminSuspensionBlocked();
    }
    // Read everything first. Transactions retry if another app changes an order.
    await db.runTransaction((tx) async {
      final account = await tx.get(accountRef);
      if (!account.exists) throw StateError('Account not found');
      final orderRefs = preview.map((o) => db.collection('orders').doc(o.id)).toList();
      final orders = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in orderRefs) {
        orders.add(await tx.get(ref));
      }
      // Read linked providers before any writes so we can release activeOrderId.
      final linkedProviders = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final snap in orders) {
        final data = snap.data();
        if (data == null || data['status'] != 'accepted') continue;
        final providerId = (data['providerId'] ?? '').toString();
        if (providerId.isNotEmpty && !linkedProviders.containsKey(providerId)) {
          linkedProviders[providerId] = await tx.get(db.collection('providers').doc(providerId));
        }
      }
      // Per-document transaction checks guard against an order progressing.
      for (final snap in orders) {
        final data = snap.data();
        if (data == null) continue;
        final status = (data['status'] ?? '').toString();
        if (const ['onTheWay', 'arrived', 'inProgress'].contains(status)) {
          throw const AdminSuspensionBlocked();
        }
      }
      for (final snap in orders) {
        final data = snap.data();
        if (data == null) continue;
        final status = (data['status'] ?? '').toString();
        if (!const ['pending', 'accepted'].contains(status)) continue;
        final providerId = (data['providerId'] ?? '').toString();
        final linked = linkedProviders[providerId];
        if (linked != null && linked.data()?['activeOrderId'] == snap.id) {
          // Never leave the provider locked to an administratively cancelled order.
          tx.update(linked.reference, {'activeOrderId': FieldValue.delete()});
        }
        tx.update(snap.reference, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        final recipient = user.type == 'customer'
            ? (data['providerId'] ?? '').toString()
            : (data['customerId'] ?? '').toString();
        // For an unassigned pending order there is no assigned provider to notify.
        if (recipient.isNotEmpty) {
          tx.set(db.collection('notifications').doc(), {
            'recipientId': recipient,
            'type': 'adminCancellation',
            'orderId': snap.id,
            'title': 'تم إلغاء الطلب',
            'body': 'تم إلغاء الطلب بسبب إيقاف حساب الطرف الآخر من الإدارة.',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
          });
        }
      }
      if (user.type == 'provider') {
        tx.update(accountRef, {'isSuspended': true, 'isAvailable': false});
      } else {
        tx.update(accountRef, {'isSuspended': true});
      }
    });
  }

}

/// Search input normalization: collapse all whitespace and ignore case.
String normalizeUserSearch(String value) => value
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase();

bool matchesUserSearch(AdminUserData user, String input) {
  final query = normalizeUserSearch(input);
  if (query.isEmpty) return true;
  final searchable = normalizeUserSearch(
    '${user.firstName} ${user.lastName} ${user.email} ${user.phone}',
  );
  return searchable.contains(query);
}

List<AdminUserData> filterAdminUsers(
  List<AdminUserData> users, {
  required String search,
  required String type,
  required String status,
}) => users.where((user) {
  final typeMatches = type == 'all' || user.type == type;
  final statusMatches = status == 'all' ||
      (status == 'suspended' ? user.isSuspended : !user.isSuspended);
  return typeMatches && statusMatches && matchesUserSearch(user, search);
}).toList();
