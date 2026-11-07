import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_model.dart';
import 'order_status_notification.dart';
import 'order.dart';

/// Summary of the service provider assigned to an order (#26).
class AssignedProvider {
  /// Creates a provider summary.
  ///
  /// Parameters: the provider's [fullName], vehicle details
  /// ([vehicleTitle], [vehicleColor], [plateNumber], [plateNumberLatin]) and
  /// an optional [rating].
  const AssignedProvider({
    required this.fullName,
    required this.vehicleTitle,
    required this.vehicleColor,
    required this.plateNumber,
    this.plateNumberLatin = '',
    this.rating,
  });

  final String fullName;
  final String vehicleTitle;
  final String vehicleColor;
  final String plateNumber;

  /// The same plate with Latin letters, e.g. "4821 RSE".
  final String plateNumberLatin;

  /// Average rating, or null when the provider has not been rated yet.
  final num? rating;

  /// Builds a summary from a provider document.
  ///
  /// Parameters: [map] is the raw data of a document in `providers`.
  /// Returns: an [AssignedProvider]; missing text fields become empty strings.
  factory AssignedProvider.fromMap(Map<String, dynamic> map) {
    String read(String key) => (map[key] ?? '').toString().trim();

    final vehicleParts = [
      read('vehicleBrand'),
      read('vehicleModel'),
      read('vehicleYear'),
    ].where((part) => part.isNotEmpty);

    return AssignedProvider(
      fullName: '${read('firstName')} ${read('lastName')}'.trim(),
      vehicleTitle: vehicleParts.join(' '),
      vehicleColor: read('vehicleColor'),
      plateNumber: read('plateNumberArabic'),
      plateNumberLatin: read('plateNumberLatin'),
      rating: map['rating'] as num?,
    );
  }
}

/// MODEL: reads a customer's orders and their assigned providers.
class CustomerOrdersModel {
  /// Creates the model.
  ///
  /// Parameters: [firestore] can be injected in tests; the default
  /// Firestore instance is used otherwise.
  CustomerOrdersModel({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  static const _ordersCollection = 'orders';
  static const _providersCollection = 'providers';
  static const _customerIdField = 'customerId';

  /// Returns the injected Firestore instance, or the default one.
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  /// Streams every order placed by one customer, newest first.
  ///
  /// Sorting is done here rather than in the query so Firestore does not
  /// need a composite index.
  ///
  /// Parameters: [customerId] is the customer's user id.
  /// Returns: a stream that emits the full, sorted list on every change.
  Stream<List<ServiceOrder>> watchCustomerOrders(String customerId) {
    return _firestore
        .collection(_ordersCollection)
        .where(_customerIdField, isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
          final orders = snapshot.docs
              .map((doc) => ServiceOrder.fromMap(doc.id, doc.data()))
              .toList();
          orders.sort(_newestFirst);
          return orders;
        });
  }

  /// Streams a single order so its details stay up to date.
  ///
  /// Parameters: [orderId] is the order document id.
  /// Returns: a stream of the order, or null once it no longer exists.
  Stream<ServiceOrder?> watchOrder(String orderId) {
    return _firestore
        .collection(_ordersCollection)
        .doc(orderId)
        .snapshots()
        .map((doc) {
          final data = doc.data();
          return data == null ? null : ServiceOrder.fromMap(doc.id, data);
        });
  }

  /// Loads the provider assigned to an order.
  ///
  /// Parameters: [providerId] is the provider's user id.
  /// Returns: the provider summary, or null if the document does not exist.
  Future<AssignedProvider?> getAssignedProvider(String providerId) async {
    final doc = await _firestore
        .collection(_providersCollection)
        .doc(providerId)
        .get();
    final data = doc.data();
    return data == null ? null : AssignedProvider.fromMap(data);
  }

  /// Compares two orders by creation time, newest first.
  ///
  /// Orders still waiting for their server timestamp are placed first.
  ///
  /// Parameters: the two orders [a] and [b] being compared.
  /// Returns: a negative number when [a] should come before [b].
  static int _newestFirst(ServiceOrder a, ServiceOrder b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return -1;
    if (bTime == null) return 1;
    return bTime.compareTo(aTime);
  }

  /// How long the customer can still cancel after a provider accepts (#20).
  static const cancelWindow = Duration(minutes: 2);

  /// Tells whether an order can still be cancelled by the customer (#20).
  ///
  /// Parameters: [order] is the order to check and [now] is the current
  /// time.
  /// Returns: true while the order is waiting for a provider, or accepted
  /// less than [cancelWindow] ago.
  static bool canCancel(ServiceOrder order, DateTime now) {
    if (order.status == OrderStatus.pending) return true;
    final left = cancelTimeLeft(order, now);
    return left != null && left > Duration.zero;
  }

  /// Returns how long the customer has left to cancel an accepted order.
  ///
  /// Parameters: [order] is the order to check and [now] is the current
  /// time.
  /// Returns: the time left (never negative), or null when the order is
  /// not accepted or has no acceptance time.
  static Duration? cancelTimeLeft(ServiceOrder order, DateTime now) {
    final acceptedAt = order.acceptedAt;
    if (order.status != OrderStatus.accepted || acceptedAt == null) {
      return null;
    }
    final left = acceptedAt.add(cancelWindow).difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// Cancels an order for the customer (#20).
  ///
  /// Runs in a transaction, so the order is only cancelled if it can still
  /// be cancelled at the moment of saving, even if a provider changed it
  /// a second earlier.
  ///
  /// Parameters: [orderId] is the order to cancel.
  /// Returns: nothing. Throws [StateError] when the order can no longer be
  /// cancelled.
  Future<void> cancelOrder(String orderId) async {
    final firestore = _firestoreOverride ?? FirebaseFirestore.instance;
    final ref = firestore.collection(_ordersCollection).doc(orderId);
    await firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) throw StateError('Order not found');
      final order = ServiceOrder.fromMap(snapshot.id, data);
      if (!canCancel(order, DateTime.now())) {
        throw StateError('Order can no longer be cancelled');
      }
      final providerId = order.providerId;
      if (providerId != null && providerId.isNotEmpty) {
        final providerRef = firestore
            .collection(_providersCollection)
            .doc(providerId);
        final providerSnapshot = await transaction.get(providerRef);
        if (providerSnapshot.data()?['activeOrderId'] == orderId) {
          transaction.update(providerRef, {
            'activeOrderId': FieldValue.delete(),
          });
        }
        // Tell the provider who accepted it, so the order does not just
        // disappear from their screen.
        transaction.set(
          firestore
              .collection('notifications')
              .doc('${order.id}_orderCancelled_${order.providerId}'),
          NotificationSender.orderCancelledData(order),
        );
      }
      // Self-cancellation already has UI feedback; notify only the provider.
      transaction.update(ref, {
        'status': OrderStatus.cancelled,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Tells whether a pending order has passed its expiry time (#21).
  ///
  /// Parameters: [order] is the order to check and [now] is the current
  /// time.
  /// Returns: true when the order is still pending and [now] is at or after
  /// its expiresAt time.
  static bool isExpired(ServiceOrder order, DateTime now) {
    final expiresAt = order.expiresAt;
    return order.status == OrderStatus.pending &&
        expiresAt != null &&
        !expiresAt.isAfter(now);
  }

  /// Moves a pending order to autoCancelled once its response window has
  /// passed (#21).
  ///
  /// Runs in a transaction that reads the order again before writing, so an
  /// order a provider accepted in the last second is left untouched.
  ///
  /// Parameters: [orderId] is the order to check.
  /// Returns: true when the order was auto-cancelled, false when it was left
  /// unchanged (not found, no longer pending, or not expired yet).
  Future<bool> autoCancelIfExpired(String orderId) async {
    final firestore = _firestoreOverride ?? FirebaseFirestore.instance;
    final ref = firestore.collection(_ordersCollection).doc(orderId);
    return firestore.runTransaction<bool>((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data == null) return false;
      final order = ServiceOrder.fromMap(snapshot.id, data);
      if (!isExpired(order, DateTime.now())) return false;
      OrderStatusNotification.write(
        transaction,
        firestore,
        orderId,
        data,
        OrderStatus.autoCancelled,
      );
      transaction.update(ref, {
        'status': OrderStatus.autoCancelled,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }
}
