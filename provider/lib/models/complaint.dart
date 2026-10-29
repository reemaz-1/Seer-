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
    );
  }

  /// Converts a new complaint to a Firestore map.
  /// createdAt uses the server time; resolvedAt stays null until resolved.
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
    };
  }
}