import 'package:cloud_firestore/cloud_firestore.dart';

///====================================================================================
/// SHARED CONTRACT for the orders feature.
/// The same file exists in customer/ and provider/ — keep them identical.
/// Don't rename anything here without telling the team first.

/// Every possible value of an order's `status` field.
/// Always use these constants instead of typing the text yourself
///======================================================================================

class OrderStatus {
  static const pending = 'pending';
  static const accepted = 'accepted';
  static const rejected = 'rejected';
  static const autoCancelled = 'auto_cancelled';
  static const cancelled = 'cancelled';
  static const onTheWay = 'on_the_way';
  static const arrived = 'arrived';
  static const inProgress = 'in_progress';
  static const completed = 'completed';

  /// Statuses where the provider is still working on the order ("current order").
  static const active = [accepted, onTheWay, arrived, inProgress];
}

/// Provider's time to respond, and customer's time to cancel after acceptance.
const Duration orderTimeWindow = Duration(minutes: 2);

class Order {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String providerId;
  final String vehicleId;
  final Map<String, String> vehicle; // brand, model, plateNumber
  final String serviceCategory; // e.g. 'fuel'
  final String serviceOption; // e.g. 'petrol91'
  final GeoPoint location;
  final GeoPoint? dropoffLocation; // towing only
  final String note;
  final String status;
  final DateTime? createdAt; // null for a moment until the server sets it
  final DateTime? acceptedAt;
  final bool paymentConfirmed;

  const Order({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.providerId,
    required this.vehicleId,
    required this.vehicle,
    required this.serviceCategory,
    required this.serviceOption,
    required this.location,
    this.dropoffLocation,
    required this.note,
    required this.status,
    this.createdAt,
    this.acceptedAt,
    required this.paymentConfirmed,
  });


  /// Last moment the provider can accept or reject.
  DateTime? get responseDeadline => createdAt?.add(orderTimeWindow);

  /// Last moment the customer can cancel after the provider accepted.
  DateTime? get cancelDeadline => acceptedAt?.add(orderTimeWindow);


  /// Build an Order from a Firestore document.
  factory Order.fromMap(String id, Map<String, dynamic> map) {
    return Order(
      id: id,
      customerId: (map['customerId'] ?? '') as String,
      customerName: (map['customerName'] ?? '') as String,
      customerPhone: (map['customerPhone'] ?? '') as String,
      providerId: (map['providerId'] ?? '') as String,
      vehicleId: (map['vehicleId'] ?? '') as String,
      vehicle: Map<String, String>.from((map['vehicle'] ?? const {}) as Map),
      serviceCategory: (map['serviceCategory'] ?? '') as String,
      serviceOption: (map['serviceOption'] ?? '') as String,
      location: (map['location'] as GeoPoint?) ?? const GeoPoint(0, 0),
      dropoffLocation: map['dropoffLocation'] as GeoPoint?,
      note: (map['note'] ?? '') as String,
      status: (map['status'] ?? OrderStatus.pending) as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      acceptedAt: (map['acceptedAt'] as Timestamp?)?.toDate(),
      paymentConfirmed: map['paymentConfirmed'] == true,
    );
  }
}//end Order Class

/// The order while the customer is still filling it in (memory only, not saved).
/// Dima fills the service, vehicle and note; Atheer fills the locations;
/// Sarah saves it as a real order when the customer confirms.
class OrderDraft {
  String? serviceCategory;
  String? serviceOption;
  String? vehicleId;
  Map<String, String>? vehicle; // brand, model, plateNumber
  String note = '';
  GeoPoint? location;
  GeoPoint? dropoffLocation;

  bool get isComplete =>
      serviceCategory != null &&
      serviceOption != null &&
      vehicleId != null &&
      location != null;


  /// The map saved as a brand-new order. Status always starts as pending.
  Map<String, dynamic> toNewOrderMap({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String providerId,
  }) {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'providerId': providerId,
      'vehicleId': vehicleId,
      'vehicle': vehicle ?? <String, String>{},
      'serviceCategory': serviceCategory,
      'serviceOption': serviceOption,
      'location': location,
      'dropoffLocation': dropoffLocation,
      'note': note,
      'status': OrderStatus.pending,
      'createdAt': FieldValue.serverTimestamp(),
      'acceptedAt': null,
      'paymentConfirmed': false,
    };
  }
}