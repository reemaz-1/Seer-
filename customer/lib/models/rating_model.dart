import 'package:cloud_firestore/cloud_firestore.dart';

import 'order.dart';

/// MODEL: the immutable star value saved for a completed order.
class OrderRating {
  /// Takes the saved [stars]; creates a read-only rating.
  const OrderRating(this.stars);
  final int stars;
}

/// Persistence failure codes; the controller supplies user-facing messages.
enum RatingFailure { invalidStars, notEligible, alreadyRated, providerMissing }

/// A typed rating failure, independent of presentation language.
class RatingException implements Exception {
  /// Takes the failed persistence [reason]; creates the domain exception.
  const RatingException(this.reason);
  final RatingFailure reason;
}

/// MODEL: stores one rating and updates the provider aggregate atomically.
class RatingModel {
  /// Takes an optional Firestore client; creates the persistence gateway.
  RatingModel({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _store => _injected ?? FirebaseFirestore.instance;

  /// Takes [orderId]; returns its persisted rating stream.
  Stream<OrderRating?> watch(String orderId) =>
      _store.collection('ratings').doc(orderId).snapshots().map((doc) {
        final stars = doc.data()?['stars'];
        return stars is int ? OrderRating(stars) : null;
      });

  /// Takes the order, owner and stars; commits both documents or throws.
  Future<void> submit({
    required String orderId,
    required String customerId,
    required int stars,
  }) async {
    if (stars < 1 || stars > 5) {
      throw const RatingException(RatingFailure.invalidStars);
    }
    final ratingRef = _store.collection('ratings').doc(orderId);
    final orderRef = _store.collection('orders').doc(orderId);
    RatingFailure? result;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        result = await _store.runTransaction<RatingFailure?>((tx) async {
          final order = (await tx.get(orderRef)).data();
          final previous = await tx.get(ratingRef);
          if (order == null ||
              order['customerId'] != customerId ||
              order['status'] != OrderStatus.completed ||
              order['providerId'] is! String ||
              (order['providerId'] as String).isEmpty) {
            return RatingFailure.notEligible;
          }
          if (previous.exists) return RatingFailure.alreadyRated;
          final providerId = order['providerId'] as String;
          final providerRef = _store.collection('providers').doc(providerId);
          final provider = (await tx.get(providerRef)).data();
          if (provider == null) return RatingFailure.providerMissing;
          final count = (provider['ratingCount'] as int? ?? 0) + 1;
          final sum = (provider['ratingSum'] as num? ?? 0) + stars;
          tx.set(ratingRef, {
            'orderId': orderId,
            'customerId': customerId,
            'providerId': providerId,
            'stars': stars,
            'createdAt': FieldValue.serverTimestamp(),
          });
          tx.update(providerRef, {
            'ratingCount': count,
            'ratingSum': sum,
            'rating': sum / count,
            'lastRatingOrderId': orderId,
          });
          return null;
        });
        break;
      } on FirebaseException catch (error) {
        // Concurrent ratings can fail the aggregate rule before Firestore
        // reports the version conflict. Re-read in a fresh transaction; never
        // reuse a stale count or weaken the aggregate checks.
        if (error.code == 'permission-denied' && attempt < 2) continue;
        rethrow;
      }
    }
    if (result != null) throw RatingException(result);
  }
}
