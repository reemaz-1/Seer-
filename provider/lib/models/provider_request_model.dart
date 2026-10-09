import 'package:cloud_firestore/cloud_firestore.dart';

import 'order.dart';

/// A request became unavailable before the provider's transaction committed.
class RequestUnavailable implements Exception {
  /// Takes no inputs; creates the expected stale-request error.
  const RequestUnavailable();
}

/// Shared eligibility checks for the list, details and transaction retries.
class RequestEligibility {
  /// Takes no inputs; prevents instances of this utility class.
  RequestEligibility._();

  /// Takes an [order], [providerId] and current [now]; returns true only while
  /// this candidate may answer. Missing deadlines fail closed.
  static bool canRespond(ServiceOrder order, String providerId, DateTime now) =>
      providerId.isNotEmpty &&
      order.status == OrderStatus.pending &&
      (order.providerId == null || order.providerId!.isEmpty) &&
      order.candidateProviderIds.contains(providerId) &&
      !order.rejectedBy.contains(providerId) &&
      order.expiresAt != null &&
      order.expiresAt!.isAfter(now);
}

/// Injectable boundary for request snapshots and atomic provider decisions.
abstract class RequestRepository {
  /// Takes [providerId]; returns its candidate orders, including status changes.
  Stream<List<ServiceOrder>> watchCandidates(String providerId);

  /// Takes [orderId] and [providerId]; completes after accepting or throws.
  Future<void> accept(String orderId, String providerId);

  /// Takes [orderId] and [providerId]; completes after declining or throws.
  Future<void> reject(String orderId, String providerId);
}

/// MODEL: reads candidate orders and arbitrates responses with transactions.
class ProviderRequestModel implements RequestRepository {
  /// Takes optional Firestore and clock dependencies; creates a request gateway.
  ProviderRequestModel({FirebaseFirestore? firestore, DateTime Function()? now})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _now = now ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final DateTime Function() _now;

  /// Takes no inputs; returns the canonical orders collection.
  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  /// Takes [providerId]; streams candidate snapshots using one array index.
  /// The controller filters status/expiry locally to avoid a composite index.
  @override
  Stream<List<ServiceOrder>> watchCandidates(String providerId) => _orders
      .where('candidateProviderIds', arrayContains: providerId)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => ServiceOrder.fromMap(doc.id, doc.data()))
            .toList(),
      );

  /// Takes a fresh [snapshot] and [providerId]; returns an eligible order or
  /// null without writing. This runs again on every transaction retry.
  ServiceOrder? _availableOrder(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String providerId,
  ) {
    final data = snapshot.data();
    if (data == null) return null;
    final order = ServiceOrder.fromMap(snapshot.id, data);
    if (!RequestEligibility.canRespond(order, providerId, _now())) {
      return null;
    }
    return order;
  }

  /// Takes an order and candidate id; atomically claims the pending request.
  /// Returns after committing a server timestamp, never a phone timestamp.
  @override
  Future<void> accept(String orderId, String providerId) async {
    final ref = _orders.doc(orderId);
    final accepted = await _firestore.runTransaction<bool>((transaction) async {
      if (_availableOrder(await transaction.get(ref), providerId) == null) {
        return false;
      }
      transaction.update(ref, {
        'status': OrderStatus.accepted,
        'providerId': providerId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
    // Keep domain exceptions outside SDK callbacks for native/web consistency.
    if (!accepted) throw const RequestUnavailable();
  }

  /// Takes an order and candidate id; adds only that candidate's rejection in
  /// a transaction. Returns after global rejection only when every candidate did.
  @override
  Future<void> reject(String orderId, String providerId) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final rejected = await _rejectTransaction(orderId, providerId);
        if (!rejected) throw const RequestUnavailable();
        return;
      } on FirebaseException catch (error) {
        // Concurrent arrayUnion commits can make the final-rejection rule fail
        // before the SDK reports a version conflict. Re-read once in a NEW
        // transaction; never weaken the rule or reuse the earlier snapshot.
        if (attempt == 0 && error.code == 'permission-denied') continue;
        rethrow;
      }
    }
  }

  /// Takes response ids; returns whether one fresh rejection transaction commits.
  Future<bool> _rejectTransaction(String orderId, String providerId) async {
    final ref = _orders.doc(orderId);
    return _firestore.runTransaction<bool>((transaction) async {
      final order = _availableOrder(await transaction.get(ref), providerId);
      if (order == null) return false;
      final rejected = {...order.rejectedBy, providerId};
      final allRejected = order.candidateProviderIds.every(rejected.contains);
      transaction.update(ref, {
        'rejectedBy': FieldValue.arrayUnion([providerId]),
        if (allRejected) 'status': OrderStatus.rejected,
      });
      return true;
    });
  }
}
