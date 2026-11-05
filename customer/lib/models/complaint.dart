import 'package:cloud_firestore/cloud_firestore.dart';

/// The status values a complaint moves through. The admin dashboard updates
/// these in #55, so every app must use exactly these strings.
class ComplaintStatus {
  /// Prevents instantiation; this class only holds constants.
  ComplaintStatus._();

  static const pending = 'pending'; // set automatically on submit (#30, #49)
  static const resolved = 'resolved'; // set by the admin after review (#55)
}//end ComplaintStatus

class ComplainantType {
  /// Prevents instantiation; this class only holds constants.
  ComplainantType._();

  static const customer = 'customer'; // customer about a provider (#30)
  static const provider = 'provider'; // provider about a customer (#49)
}//end ComplainantType

/// MODEL: one complaint in the `complaints` collection.
///
/// The same shape is used by the customer app (#30), the provider app (#49)
/// and the admin dashboard (#54, #55), so field names must stay identical.
class Complaint {
  /// Creates a complaint from the named fields; returns an immutable complaint.
  const Complaint({
    required this.id,
    required this.complainantId,
    required this.complainantType,
    required this.againstId,
    required this.orderId,
    required this.description,
    required this.status,
    this.createdAt,
    this.resolvedAt,
    this.customerName,
    this.customerPhone,
    this.providerName,
    this.serviceLabel,
    this.vehicleTitle,
    this.orderPrice,
    this.orderStatus,
  });

  /// The Firestore document id.
  final String id;

  /// The uid of the user who submitted the complaint.
  final String complainantId;

  /// One of [ComplainantType] values.
  final String complainantType;

  /// The uid of the user the complaint is about.
  final String againstId;

  /// The order the complaint is related to.
  final String orderId;

  /// The complaint text written by the user.
  final String description;

  /// One of [ComplaintStatus] values.
  final String status;

  /// Server time of submission. null until the server sets it.
  final DateTime? createdAt;

  /// Set by the admin when the complaint is resolved (#55).
  final DateTime? resolvedAt;

  // ---- Order snapshot: copied at submit time so the admin sees the order
  // ---- as it was, even if it changes later. All optional (null = unknown).

  /// Customer's name at the time of the complaint.
  final String? customerName;

  /// Customer's phone at the time of the complaint.
  final String? customerPhone;

  /// Assigned provider's name at the time of the complaint.
  final String? providerName;

  /// Service label, e.g. "بطارية - تفعيل".
  final String? serviceLabel;

  /// Vehicle title, e.g. "تويوتا كامري 2022".
  final String? vehicleTitle;

  /// Final price if known, otherwise the estimated price.
  final num? orderPrice;

  /// The order status when the complaint was sent.
  final String? orderStatus;

  /// Parses document [id] and Firestore [map]; returns a typed complaint.
  factory Complaint.fromMap(String id, Map<String, dynamic> map) {
    return Complaint(
      id: id,
      complainantId: (map['complainantId'] ?? '') as String,
      complainantType: (map['complainantType'] ?? '') as String,
      againstId: (map['againstId'] ?? '') as String,
      orderId: (map['orderId'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      status: (map['status'] ?? ComplaintStatus.pending) as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      customerName: map['customerName'] as String?,
      customerPhone: map['customerPhone'] as String?,
      providerName: map['providerName'] as String?,
      serviceLabel: map['serviceLabel'] as String?,
      vehicleTitle: map['vehicleTitle'] as String?,
      orderPrice: map['orderPrice'] as num?,
      orderStatus: map['orderStatus'] as String?,
    );
  }

  /// Converts a new complaint to a Firestore map.
  /// createdAt uses the server time; resolvedAt stays null until resolved.
  /// Snapshot fields are written only when they have a value, because the
  /// security rules accept a missing field but not a null one.
  Map<String, dynamic> toMap() {
    return {
      'complainantId': complainantId,
      'complainantType': complainantType,
      'againstId': againstId,
      'orderId': orderId,
      'description': description,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'resolvedAt': null,
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (providerName != null) 'providerName': providerName,
      if (serviceLabel != null) 'serviceLabel': serviceLabel,
      if (vehicleTitle != null) 'vehicleTitle': vehicleTitle,
      if (orderPrice != null) 'orderPrice': orderPrice,
      if (orderStatus != null) 'orderStatus': orderStatus,
    };
  }
}