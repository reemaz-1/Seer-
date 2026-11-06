import 'package:cloud_firestore/cloud_firestore.dart';

import 'complaint.dart';

/// MODEL: reads complaints from Firestore for the admin dashboard (#54, #55).
class ComplaintsModel {
  /// Creates the model; [firestore] can be injected in tests.
  ComplaintsModel({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// The `complaints` collection.
  CollectionReference<Map<String, dynamic>> get _complaints =>
      _firestore.collection('complaints');

  /// Listens to all complaints, newest first (#54).
  ///
  /// Returns: a stream of complaints that updates by itself.
  Stream<List<Complaint>> streamAll() {
    return _complaints.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Complaint.fromMap(doc.id, doc.data()))
          .toList();
      // Sorted here instead of in the query, so a complaint that is still
      // waiting for its server time is never dropped.
      list.sort(_newestFirst);
      return list;
    });
  }

  /// Loads one complaint (#55).
  ///
  /// Parameters: [id] is the complaint document id.
  /// Returns: the complaint, or null if it does not exist.
  Future<Complaint?> fetchById(String id) async {
    final doc = await _complaints.doc(id).get();
    final data = doc.data();
    return data == null ? null : Complaint.fromMap(doc.id, data);
  }

  /// Counts all complaints written about one user (#55).
  /// Used to spot a customer or a provider who is complained about again
  /// and again.
  ///
  /// Parameters: [userId] is the user's id (customer or provider).
  /// Returns: the number of complaints about that user.
  Future<int> countAgainst(String providerId) async {
    final result = await _complaints
        .where('againstId', isEqualTo: providerId)
        .count()
        .get();
    return result.count ?? 0;
  }

 /// Listens to one complaint, so the details page updates by itself (#55).
  ///
  /// Parameters: [id] is the complaint document id.
  /// Returns: a stream with the complaint, or null if it does not exist.
  Stream<Complaint?> watchById(String id) {
    return _complaints.doc(id).snapshots().map((doc) {
      final data = doc.data();
      return data == null ? null : Complaint.fromMap(doc.id, data);
    });
  }

  /// Marks a pending complaint as resolved (#55).
  ///
  /// Parameters: [id] is the complaint document id.
  /// Throws [StateError] if the complaint is missing or already resolved.
  Future<void> markResolved(String id) {
    final ref = _complaints.doc(id);
    // A transaction, so two admins cannot resolve the same complaint twice.
    return _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(ref);
      final data = doc.data();
      if (data == null) throw StateError('missing');
      if (data['status'] == ComplaintStatus.resolved) {
        throw StateError('already resolved');
      }
      transaction.update(ref, {
        'status': ComplaintStatus.resolved,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Compares two complaints by creation time, newest first.
  /// A complaint without a time yet is placed first.
  static int _newestFirst(Complaint a, Complaint b) {
    final aTime = a.createdAt;
    final bTime = b.createdAt;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return -1;
    if (bTime == null) return 1;
    return bTime.compareTo(aTime);
  }
}