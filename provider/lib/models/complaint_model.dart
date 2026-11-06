import 'package:cloud_firestore/cloud_firestore.dart';

import 'complaint.dart';

/// Thrown when the provider already sent a complaint for this order.
class ComplaintAlreadyExists implements Exception {
  const ComplaintAlreadyExists();
}

/// MODEL: reads and writes the provider's complaints in Firestore (#49).
class ComplaintModel {
  /// Takes an optional [firestore]; it is resolved on first use, so creating
  /// the model never needs Firebase.
  ComplaintModel({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;

  FirebaseFirestore get _firestore => _injected ?? FirebaseFirestore.instance;

  /// The `complaints` collection.
  CollectionReference<Map<String, dynamic>> get _complaints =>
      _firestore.collection('complaints');

  /// Takes an [orderId]; returns the provider's complaint document id.
  /// One complaint per order: the id is fixed by the order id, and differs
  /// from the customer's complaint on the same order.
  static String idFor(String orderId) =>
      '${orderId}_${ComplainantType.provider}';

  /// Takes an [orderId]; returns a live stream with the provider's
  /// complaint on that order, or null when none was sent yet.
  Stream<Complaint?> watchComplaintForOrder(String orderId) {
    return _complaints.doc(idFor(orderId)).snapshots().map((doc) {
      final data = doc.data();
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

  /// Takes a new [complaint] and saves it.
  /// Throws [ComplaintAlreadyExists] if this order already has one.
  Future<void> submit(Complaint complaint) async {
    final ref = _complaints.doc(idFor(complaint.orderId));
    // Check first so the provider gets a clear message instead of an error.
    final existing = await ref.get();
    if (existing.exists) throw const ComplaintAlreadyExists();
    await ref.set(complaint.toMap());
  }

  /// Takes the provider's [uid]; returns their full name, or null when it
  /// cannot be found.
  Future<String?> providerName(String uid) async {
    final data = (await _firestore.collection('providers').doc(uid).get())
        .data();
    if (data == null) return null;
    final name = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    return name.isEmpty ? null : name;
  }
}
