import 'package:cloud_firestore/cloud_firestore.dart';
 
/// The status values an order moves through. The provider app updates these
/// in #44, so both apps must use exactly these strings.
///
/// This file is a copy of customer/lib/models/order.dart with the provider's
/// database actions in OrderModel. Keep the two copies of ServiceOrder and
/// OrderStatus identical.
class OrderStatus {
  OrderStatus._();
 
  static const pending = 'pending';     // waiting for a provider (#18)
  static const accepted = 'accepted';   // a provider accepted it (#39)
  static const onTheWay = 'onTheWay';
  static const arrived = 'arrived';
  static const inProgress = 'inProgress';
  static const completed = 'completed';
  static const cancelled = 'cancelled';         // the customer cancelled (#20)
  static const rejected = 'rejected';           // the provider rejected it (#39)
  static const autoCancelled = 'autoCancelled'; // no answer within 2 minutes

  /// The statuses of an order the provider is still working on.
  static const active = [accepted, onTheWay, arrived, inProgress];
}
 
/// MODEL: one service request.
///
/// The vehicle and service details are COPIED into the order instead of only
/// keeping ids, so an order still reads correctly later even if the customer
/// edits or deletes that vehicle (#9, #10).
class ServiceOrder {
  const ServiceOrder({
    required this.id,
    required this.customerId,
    required this.vehicleId,
    required this.vehicleTitle,
    required this.vehiclePlateArabic,
    required this.vehiclePlateLatin,
    required this.serviceCategoryId,
    required this.serviceCategoryLabel,
    required this.serviceOptionId,
    required this.serviceOptionLabel,
    required this.serviceBranch,
    required this.note,
    required this.estimatedPrice,
    required this.status,
    this.customerName = '',
    this.customerPhone = '',
    this.finalPrice,
    this.createdAt,
    this.acceptedAt,
    this.pickupLocation,
    this.dropoffLocation,
    this.providerId,
    this.paymentConfirmed = false,
    this.expiresAt,
    this.completedAt,
  });
 
  final String id;
  final String customerId;
 
  /// Copied from the customer's profile so the provider can see and call them.
  final String customerName;
  final String customerPhone;
 
  // Vehicle (#14)
  final String vehicleId;
  final String vehicleTitle;        // "تويوتا كامري 2022"
  final String vehiclePlateArabic;
  final String vehiclePlateLatin;
 
  // Service (#13)
  final String serviceCategoryId;   // 'battery'
  final String serviceCategoryLabel;
  final String serviceOptionId;     // 'activation'
  final String serviceOptionLabel;
  final String serviceBranch;       // what the provider app matches on
 
  /// The customer's note (#23). Empty when none was written.
  final String note;
 
  /// What the customer was shown before confirming (#17), in riyals.
  /// null when this service has no price in lookup_data yet.
  final num? estimatedPrice;
 
  /// TODO(#46): what was actually collected, set by the provider at the end.
  final num? finalPrice;
 
  final String status;
  final DateTime? createdAt;
 
  /// Set by the provider app when it accepts (#39).
  /// Used for the 2-minute cancel window (#20).
  final DateTime? acceptedAt;
 
  /// TODO(#15): the vehicle's current location, set by the location story.
  /// Expected shape: {'lat': double, 'lng': double, 'address': String}
  final GeoPoint? pickupLocation;
 
  /// TODO(#16): the drop-off location, towing only.
  final GeoPoint? dropoffLocation;
 
  /// TODO(#18): filled in when a provider is matched / accepts.
  final String? providerId;

  /// Set to true by the provider app when it confirms the customer paid
  /// (#46). Always false when the order is created.
  final bool paymentConfirmed;

  /// When a 'pending' order stops waiting for a provider: createdAt plus
  /// two minutes (#21, #39). Used for the automatic cancellation.
  final DateTime? expiresAt;

  /// Set by the provider app when the order is completed (#44).
  final DateTime? completedAt;
 
  factory ServiceOrder.fromMap(String id, Map<String, dynamic> map) {
    return ServiceOrder(
      id: id,
      customerId: (map['customerId'] ?? '') as String,
      customerName: (map['customerName'] ?? '') as String,
      customerPhone: (map['customerPhone'] ?? '') as String,
      vehicleId: (map['vehicleId'] ?? '') as String,
      vehicleTitle: (map['vehicleTitle'] ?? '') as String,
      vehiclePlateArabic: (map['vehiclePlateArabic'] ?? '') as String,
      vehiclePlateLatin: (map['vehiclePlateLatin'] ?? '') as String,
      serviceCategoryId: (map['serviceCategoryId'] ?? '') as String,
      serviceCategoryLabel: (map['serviceCategoryLabel'] ?? '') as String,
      serviceOptionId: (map['serviceOptionId'] ?? '') as String,
      serviceOptionLabel: (map['serviceOptionLabel'] ?? '') as String,
      serviceBranch: (map['serviceBranch'] ?? '') as String,
      note: (map['note'] ?? '') as String,
      estimatedPrice: map['estimatedPrice'] as num?,
      finalPrice: map['finalPrice'] as num?,
      status: (map['status'] ?? OrderStatus.pending) as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
pickupLocation: map['pickupLocation'] as GeoPoint?,
dropoffLocation: map['dropoffLocation'] as GeoPoint?,
      providerId: map['providerId'] as String?,
      paymentConfirmed: map['paymentConfirmed'] == true,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }
 
  /// acceptedAt is not written here: the provider app sets it when it accepts.
  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'vehicleId': vehicleId,
      'vehicleTitle': vehicleTitle,
      'vehiclePlateArabic': vehiclePlateArabic,
      'vehiclePlateLatin': vehiclePlateLatin,
      'serviceCategoryId': serviceCategoryId,
      'serviceCategoryLabel': serviceCategoryLabel,
      'serviceOptionId': serviceOptionId,
      'serviceOptionLabel': serviceOptionLabel,
      'serviceBranch': serviceBranch,
      'note': note,
      'estimatedPrice': estimatedPrice,
      'finalPrice': finalPrice,
      'status': status,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'providerId': providerId,
      'paymentConfirmed': paymentConfirmed,
    };
  }
}
 
/// Talks to the database (provider side).
class OrderModel {
  OrderModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
        .map((snapshot) => snapshot.docs.isEmpty
            ? null
            : ServiceOrder.fromMap(snapshot.docs.first.id, snapshot.docs.first.data()));
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
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}
