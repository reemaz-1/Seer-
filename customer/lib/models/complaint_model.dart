import 'package:cloud_firestore/cloud_firestore.dart';

import 'complaint.dart';

/// Thrown when the customer already sent a complaint for this order.
class ComplaintAlreadyExists implements Exception {
  const ComplaintAlreadyExists();
}

/// MODEL: reads and writes the customer's complaints in Firestore (#30).
class ComplaintModel {
  /// Creates the model; [firestore] can be injected in tests.
  ComplaintModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// The `complaints` collection.
  CollectionReference<Map<String, dynamic>> get _complaints =>
      _firestore.collection('complaints');

  /// Builds the complaint document id for [orderId].
  /// One complaint per order: the id is fixed by the order id.
  static String idFor(String orderId) =>
      '${orderId}_${ComplainantType.customer}';

  /// Listens to the complaint of [orderId].
  /// Returns: a stream that emits the complaint, or null when the customer
  /// has not sent one yet. It updates by itself when the status changes.
  Stream<Complaint?> watchComplaintForOrder(String orderId) {
    return _complaints.doc(idFor(orderId)).snapshots().map((doc) {
      final data = doc.data();
      // No document yet, so there is no complaint for this order.
      if (!doc.exists || data == null) return null;
      return Complaint.fromMap(doc.id, data);
    });
  }

  /// Listens to all the complaints sent by [uid].
  /// Returns: a stream of the complaints, newest first. It updates by itself
  /// when a complaint is added or its status changes.
  Stream<List<Complaint>> watchComplaintsBy(String uid) {
    return _complaints
        .where('complainantId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Complaint.fromMap(doc.id, doc.data()))
          .toList();
      // Sorted here, so no Firestore index is needed. A complaint that was
      // just sent has no server time yet, so it counts as the newest.
      final now = DateTime.now();
      list.sort((a, b) =>
          (b.createdAt ?? now).compareTo(a.createdAt ?? now));
      return list;
    });
  }

  /// Saves a new [complaint].
  /// Throws [ComplaintAlreadyExists] if this order already has one.
  Future<void> submit(Complaint complaint) async {
    final ref = _complaints.doc(idFor(complaint.orderId));
    // Check first so the customer gets a clear message instead of an overwrite.
    final existing = await ref.get();
    if (existing.exists) throw const ComplaintAlreadyExists();
    await ref.set(complaint.toMap());
  }
}