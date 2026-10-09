import 'package:cloud_firestore/cloud_firestore.dart';

import 'order.dart';

/// Talks to the database (provider side).
class ProviderOrderModel {
  /// Takes an optional Firestore client; creates the current-order gateway.
  ProviderOrderModel({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Takes no inputs; returns the shared orders collection.
  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  /// The order this provider is working on now, or null when there is none.
  /// Updates live, so the screen changes as soon as the order does (#42).
  ///
  /// Only equality filters are used, so Firestore needs no composite index.
  Stream<ServiceOrder?> watchCurrentOrder(String providerId) {
    return _orders
        .where('providerId', isEqualTo: providerId)
        .where('status', whereIn: OrderStatus.active)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : ServiceOrder.fromMap(
                  snapshot.docs.first.id,
                  snapshot.docs.first.data(),
                ),
        );
  }

  /// Moves the order one step forward (#44): only from [from] to [to].
  ///
  /// Runs in a transaction, so a double tap or an order that changed in the
  /// meantime (for example cancelled by the customer) never skips a step.
  /// Throws [StateError] when the order is no longer at [from].
  Future<void> advanceStatus({
    required String orderId,
    required String from,
    required String to,
  }) async {
    final ref = _orders.doc(orderId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.data()?['status'] != from) {
        throw StateError('Order is no longer $from');
      }
      transaction.update(ref, {
        'status': to,
        // When each step happened, e.g. arrivedAt, for history and reports.
        '${to}At': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Completes the order and confirms the payment in one step (#44, #46),
  /// so an order can never be completed with the payment left unconfirmed.
  Future<void> completeWithPayment({
    required String orderId,
    required num? amount,
  }) async {
    final ref = _orders.doc(orderId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.data()?['status'] != OrderStatus.inProgress) {
        throw StateError('Order is no longer ${OrderStatus.inProgress}');
      }
      transaction.update(ref, {
        'status': OrderStatus.completed,
        'paymentConfirmed': true,
        'finalPrice': amount,
        'completedAt': FieldValue.serverTimestamp(),
        // The day as text (e.g. 2026-10-05) lets "today's orders" be counted
        // with equality filters only, which needs no composite index.
        'completedDay': dayKey(DateTime.now()),
      });
    });
  }

  /// Net earnings (#36): the total paid on this provider's completed
  /// orders, added up by Firestore without downloading the orders.
  Future<double> sumEarnings(String providerId) async {
    final result = await _orders
        .where('providerId', isEqualTo: providerId)
        .where('status', isEqualTo: OrderStatus.completed)
        .aggregate(sum('finalPrice'))
        .get();
    return result.getSum('finalPrice') ?? 0;
  }

  /// Number of orders this provider completed today (#36).
  Future<int> countCompletedToday(String providerId) async {
    final result = await _orders
        .where('providerId', isEqualTo: providerId)
        .where('completedDay', isEqualTo: dayKey(DateTime.now()))
        .count()
        .get();
    return result.count ?? 0;
  }

  /// A date as "yyyy-MM-dd" in the phone's local time.
  static String dayKey(DateTime date) {
    // Takes a date component; returns two decimal digits.
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
