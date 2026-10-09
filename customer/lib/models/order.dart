import 'package:cloud_firestore/cloud_firestore.dart';

/// The status values an order moves through. The provider app updates these
/// in #44, so both apps must use exactly these strings.
class OrderStatus {
  /// Prevents instantiation; takes no inputs and creates no public object.
  OrderStatus._();

  static const pending = 'pending'; // waiting for a provider (#18)
  static const accepted = 'accepted'; // a provider accepted it (#39)
  static const onTheWay = 'onTheWay';
  static const arrived = 'arrived';
  static const inProgress = 'inProgress';
  static const completed = 'completed';
  static const cancelled = 'cancelled'; // the customer cancelled (#20)
  static const rejected = 'rejected'; // the provider rejected it (#39)
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
  /// Creates an order from the named snapshot fields; returns an immutable order.
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
    this.candidateProviderIds = const [],
    this.rejectedBy = const [],
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
  final String vehicleTitle; // "تويوتا كامري 2022"
  final String vehiclePlateArabic;
  final String vehiclePlateLatin;

  // Service (#13)
  final String serviceCategoryId; // 'battery'
  final String serviceCategoryLabel;
  final String serviceOptionId; // 'activation'
  final String serviceOptionLabel;
  final String serviceBranch; // what the provider app matches on

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

  /// Every provider who received this request. The fisrt to accept it wins
  final List<String> candidateProviderIds;

  /// Providers who declined it, so it disappears from their list only.
  final List<String> rejectedBy;

  /// Set to true by the provider app when it confirms the customer paid
  /// (#46). Always false when the order is created.
  final bool paymentConfirmed;

  /// When a 'pending' order stops waiting for a provider: createdAt plus
  /// two minutes (#21, #39). Used for the automatic cancellation.
  final DateTime? expiresAt;

  /// Set by the provider app when the order is completed (#44).
  final DateTime? completedAt;

  /// Parses document [id] and Firestore [map]; returns a typed order snapshot.
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
      candidateProviderIds: List<String>.from(
        (map['candidateProviderIds'] ?? const []) as List,
      ),
      rejectedBy: List<String>.from((map['rejectedBy'] ?? const []) as List),
      paymentConfirmed: map['paymentConfirmed'] == true,
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate(),
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Takes no inputs; returns the persisted order fields.
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
      'candidateProviderIds': candidateProviderIds,
      'rejectedBy': rejectedBy,
      'paymentConfirmed': paymentConfirmed,
    };
  }
}

/// Talks to the database.
class OrderModel {
  /// Takes an optional [firestore] client; creates the order creation gateway.
  OrderModel({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Takes no inputs; returns the shared orders collection reference.
  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  /// How long a new order waits for a provider before it is cancelled.
  static const Duration responseWindow = Duration(minutes: 2);

  /// Takes [order], creates it in Firestore, and returns its new id.
  /// createdAt is set by the server, so it does not depend on the phone clock.
  /// expiresAt is written as a timestamp so both apps can compare against it
  /// without recalculating the two-minute window.
  Future<String> createOrder(ServiceOrder order) async {
    final ref = await _orders.add({
      ...order.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(responseWindow)),
      'paymentConfirmed': false,
    });
    return ref.id;
  }
}
