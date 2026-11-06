import 'package:cloud_firestore/cloud_firestore.dart';

class OrderRating {
  const OrderRating(this.stars);
  final int stars;
}

/// One immutable rating per completed order; the aggregate changes atomically.
class RatingModel {
  RatingModel({FirebaseFirestore? firestore}) : _injected = firestore;
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _store => _injected ?? FirebaseFirestore.instance;

  Stream<OrderRating?> watch(String orderId) =>
      _store.collection('ratings').doc(orderId).snapshots().map((doc) {
        final stars = doc.data()?['stars'];
        return stars is int ? OrderRating(stars) : null;
      });

  Future<void> submit({
    required String orderId,
    required String customerId,
    required int stars,
  }) async {
    if (stars < 1 || stars > 5) {
      throw StateError('اختر تقييمًا من نجمة إلى خمس نجوم.');
    }
    final ratingRef = _store.collection('ratings').doc(orderId);
    final orderRef = _store.collection('orders').doc(orderId);
    String? result;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        result = await _store.runTransaction<String?>((tx) async {
          final order = (await tx.get(orderRef)).data();
          final previous = await tx.get(ratingRef);
          if (order == null ||
              order['customerId'] != customerId ||
              order['status'] != 'completed' ||
              order['providerId'] is! String ||
              (order['providerId'] as String).isEmpty) {
            return 'يمكن تقييم مقدم الخدمة بعد اكتمال طلبك فقط.';
          }
          if (previous.exists) return 'سبق أن قيّمت هذا الطلب.';
          final providerId = order['providerId'] as String;
          final providerRef = _store.collection('providers').doc(providerId);
          final provider = (await tx.get(providerRef)).data();
          if (provider == null) return 'تعذر العثور على مقدم الخدمة.';
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
    if (result != null) throw StateError(result);
  }
}
